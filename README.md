# mac-setup

Une seule commande pour installer, réinstaller ou réparer un de mes Mac (Apple silicon ou Intel) :

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/MathieuValez/mac-setup/main/bootstrap.sh)"
```

Le script est public et ne contient rien de personnel. Il installe les Command Line Tools, Homebrew (Apple silicon)
ou MacPorts (Intel), `gh` et `chezmoi`, connecte GitHub, applique les dotfiles du dépôt privé `dotfiles`
(rôle et nom du Mac demandés la première fois), puis exécute `install.sh` de ce dépôt, qui fait le reste.
Relançable à volonté.

Le guide complet (vue d ensemble, quotidien, maintenance, dépannage, annexes) est le README du dépôt privé `dotfiles`.
