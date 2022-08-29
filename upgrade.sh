#!/bin/sh
#upgrade LARBS installation. all functions, whether modified or not,
# are copied from the original larbs.sh script

#progsfile="https://raw.githubusercontent.com/dimonf/LARBS/master/progs.csv"
#use local file, to facilitate testing before commit

progsfile=progs.csv
home_dir="/home/$USER"
repodir="$home_dir/.local/src"
aurhelper="yay"

echo ">" $repodir

installpkg() {
	pacman --noconfirm --needed -S "$1" >/dev/null 2>&1
}

maininstall() {
	# Install from main repo.
	installpkg "$1"
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
  base_dir=$2
  compile=$3
	prog_dir="$base_dir/$progname"

#  echo "trying to git into $base_dir / $prog_dir from $1"
	git -C "$base_dir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$prog_dir" 2>/dev/null ||
		{
			cd "$prog_dir" || return 1
#      echo "trying to 'git pull' in $prog_dir"
			git pull --force origin master
		}
  if [ -n $compile ]; then
    cd "$prog_dir" || exit 1
    make >/dev/null 2>&1
    sudo make install >/dev/null 2>&1
    cd /tmp || return 1
  fi
}

aurinstall() {
	echo "$installed" | grep -q "^$1$" && return 1
	$aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

pipinstall() {
	[ -x "$(command -v "pip")" ] || installpkg python-pip >/dev/null 2>&1
	yes | pip install "$1"
}

update_loop() {
    progsfile=$1
    for tag in A G g P ,; do
      case $tag in
        "A") installed=$(pacman -Qqm) ;;
        "G") installed=$(find $repodir -maxdepth 1 -mindepth 1 -type d -exec basename '{}' \;) ;;
        "g") installed="" ;;
        "P") command -v pip &>/dev/null && installed=$(pip list) ;;
        ",") installed=`pacman -Q` ;;
      esac
      #group programs by tag
      grep -E "^$tag" $progsfile | while IFS=, read tag program comment; do
         #derive destination for git based installation (separated by '|')
         echo $program | grep -q '|' &&  destination=${program#*|} && program=${program%|*}
         destination="${destination/#\~/$HOME}"
         #skip if already installed
         echo "$installed" | grep -q "^$program" && echo "[$tag]$program: already installed, ignoring" && continue
         case $tag in
           "A") aurinstall "$program" ;;
           "G") gitmakeinstall "$program" "$repodir" compile ;;
           "g") gitmakeinstall "$program" "$destination" ;;
           "P") pipinstall "$program" "$comment" ;;
           *) maininstall "$program" "$comment" ;;
         esac
       done
    done
  }

#installationloop
update_loop $1
