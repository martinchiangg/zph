# Prepend Brew Bin (/usr/local/bin/) to PATH
export PATH=/usr/local/bin:/usr/local/sbin:$PATH

alias brew='HOMEBREW_MAKE_JOBS=1 VERBOSE=1 brew'
alias buu='brew update && brew upgrade'
function brew.info {
  grep desc $(brew --prefix)/Library/Formula/*.rb | perl -ne 'm{^.*/(.*?)\.rb.*?\"(.*)"$} and print "$1|$2\n"' | column -t -s '|' | fzf --reverse
}
