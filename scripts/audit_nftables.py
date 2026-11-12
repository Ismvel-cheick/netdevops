#!/usr/bin/env python3
"""Audit automatique des règles nftables du conteneur router-fw.

Le script lit le jeu de règles actif au format JSON (``nft -j list ruleset``)
et vérifie les exigences de sécurité du projet NetDevOps :

* les chaînes ``input`` et ``forward`` ont une politique par défaut ``drop`` ;
* aucune règle ``forward`` n'accepte tout le trafic sans condition ;
* le trafic refusé est journalisé ;
* la redirection (DNAT) ne vise que le serveur web de la DMZ.

Usage : python3 scripts/audit_nftables.py [conteneur] [ip_web_dmz]
Code retour 0 si toutes les vérifications passent, 1 sinon.
"""

import json
import subprocess
import sys

CONTENEUR_DEFAUT = "router-fw"
WEB_DMZ_DEFAUT = "172.20.1.10"


def lire_ruleset(conteneur):
    """Retourne la liste des objets nftables du conteneur (format JSON)."""
    sortie = subprocess.run(
        ["docker", "exec", conteneur, "nft", "-j", "list", "ruleset"],
        capture_output=True, text=True, check=True,
    ).stdout
    return json.loads(sortie)["nftables"]


def chaines(objets):
    """Indexe les chaînes par (table, nom)."""
    return {
        (o["chain"]["table"], o["chain"]["name"]): o["chain"]
        for o in objets if "chain" in o
    }


def regles(objets, table, chaine):
    """Liste des expressions de chaque règle d'une chaîne."""
    return [
        o["rule"]["expr"] for o in objets
        if "rule" in o and o["rule"]["table"] == table and o["rule"]["chain"] == chaine
    ]


def verifier_politique_drop(objets):
    """Les chaînes input et forward doivent refuser par défaut."""
    index = chaines(objets)
    resultats = []
    for nom in ("input", "forward"):
        chaine = index.get(("filter", nom))
        ok = chaine is not None and chaine.get("policy") == "drop"
        resultats.append((f"Politique 'drop' sur la chaîne {nom}", ok))
    return resultats


def verifier_pas_accept_global(objets):
    """Aucune règle forward ne doit être un simple 'accept' sans condition."""
    fautives = [
        expr for expr in regles(objets, "filter", "forward")
        if len(expr) == 1 and "accept" in expr[0]
    ]
    return [("Aucun 'accept' inconditionnel dans forward", not fautives)]


def verifier_journalisation(objets):
    """Le trafic refusé doit être journalisé (règle 'log')."""
    journalise = any(
        "log" in element
        for expr in regles(objets, "filter", "forward")
        for element in expr
    )
    return [("Journalisation des paquets refusés (forward)", journalise)]


def verifier_dnat(objets, web_dmz):
    """Les règles DNAT ne doivent rediriger que vers le serveur web de la DMZ."""
    cibles = {
        element["dnat"].get("addr")
        for expr in regles(objets, "nat", "prerouting")
        for element in expr if "dnat" in element
    }
    return [(f"DNAT uniquement vers {web_dmz} (trouvé : {sorted(cibles)})",
             cibles == {web_dmz})]


def main():
    """Lance toutes les vérifications et affiche un rapport."""
    conteneur = sys.argv[1] if len(sys.argv) > 1 else CONTENEUR_DEFAUT
    web_dmz = sys.argv[2] if len(sys.argv) > 2 else WEB_DMZ_DEFAUT

    try:
        objets = lire_ruleset(conteneur)
    except (subprocess.CalledProcessError, KeyError, json.JSONDecodeError) as erreur:
        print(f"[ECHEC] Lecture des règles de {conteneur} impossible : {erreur}")
        return 1

    resultats = (
        verifier_politique_drop(objets)
        + verifier_pas_accept_global(objets)
        + verifier_journalisation(objets)
        + verifier_dnat(objets, web_dmz)
    )

    print(f"Audit nftables du conteneur {conteneur}")
    for libelle, ok in resultats:
        print(f"  [{'OK' if ok else 'ECHEC'}] {libelle}")
    echecs = sum(1 for _, ok in resultats if not ok)
    print(f"Résultat : {len(resultats) - echecs} OK, {echecs} échec(s)")
    return 1 if echecs else 0


if __name__ == "__main__":
    sys.exit(main())
