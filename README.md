# dotfiles

One repo for every machine. Each app is a folder; `manifest.txt` says where each folder goes on Linux and Windows.

Get the repo skeleton (root files only, no app folders yet), then install what you want:

    # Arch
    git clone --depth 1 --filter=blob:none --sparse git@github.com:YOUR-USER/dotfiles.git ~/.dotfiles
    bash ~/.dotfiles/dot install nvim        # or: install all

    # Windows (PowerShell)
    git clone --depth 1 --filter=blob:none --sparse git@github.com:YOUR-USER/dotfiles.git $HOME\.dotfiles
    pwsh -ExecutionPolicy Bypass -File $HOME\.dotfiles\dot.ps1 install nvim

Edit your config normally; the live folder is a link into this repo. Commit from `~/.dotfiles`.
