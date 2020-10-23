#!/usr/bin/env bash

# Directories
HIPPOKAMPE_GENERAL="/etc/hippokampe"
HIPPOKAMPE_BROWSERS="${HIPPOKAMPE_GENERAL}/browsers"
DESTINATION="/tmp"

# Binaries for linux
VERSION_API="v0.8.0-alpha"
VERSION_CLI="v0.7.5-alpha"
VERSION_DAEMON="v0.7.5-alpha"

HIPPOKAMPE_API="https://github.com/hippokampe/api/releases/download/${VERSION_API}/api"
HIPPOKAMPE_CLI="https://github.com/hippokampe/cli/releases/download/${VERSION_CLI}/hbtn"
HIPPOKAMPE_DAEMON="https://github.com/hippokampe/cli/releases/download/${VERSION_CLI}/hippokamped"


if [ "$EUID" -ne 0 ]; then
  echo "Please run as root. sudo ./setup.py"
  exit
fi

if [[ "$OSTYPE" != "linux-gnu"* ]]; then
  echo "Yet is not support to ${OSTYPE}"
  exit
fi

download_package() {
  PACKAGE_URL="$1"
  PACKAGE_NAME="$2"
  DEST="${DESTINATION}/${PACKAGE_NAME}"

  echo "Downloading ${PACKAGE_NAME} from ${PACKAGE_URL}"
  curl -LJ "${PACKAGE_URL}" -o "${DEST}"
  chmod +x "${DEST}"

  echo
}

install_package() {
  PACKAGES="$1"
  for i in ${PACKAGES} ; do
      echo "Installing $i in /bin/$i"
      mv "${DESTINATION}/$i" "/bin/$i"
  done
}

# Check for dependencies
echo "Checking dependencies"

check_dependency() {
  COMMAND="$1"
  if ! command -v "${COMMAND}" &> /dev/null
  then
    echo "Dependency ${COMMAND} could not be found"

    # If the dep is jq will download and install
    if [ "${COMMAND}" == "jq" ]; then
      download_package "https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64" "jq"
      install_package "jq"
    elif [ "${COMMAND}" == "npm" ]; then
      curl -s https://install-node.now.sh | bash -s --
      npm install -g npm
      npm update
      npm install
    else
      exit
    fi
  fi
}

check_dependency "npm"
check_dependency "curl"
check_dependency "jq"

# Basic structure creation
if [ -d  "${HIPPOKAMPE_GENERAL}" ]
then
    echo "Directory ${HIPPOKAMPE_GENERAL} exists."
    while true;
    do
    # shellcheck disable=SC2162
    read -p "Do you wish to generate the hippokampe config again? (yes/no): " yn
    case $yn in
        [Yy]* )
          rm -rf "${HIPPOKAMPE_GENERAL}"
          mkdir -p "${HIPPOKAMPE_BROWSERS}";
          break ;;
        [Nn]* )
          exit;;
        * ) echo "Please answer yes or no.";;
    esac
    done
else
    mkdir -p "${HIPPOKAMPE_BROWSERS}"
fi


# Downloading browsers
echo
echo "Downloading browsers"
sudo PLAYWRIGHT_BROWSERS_PATH="${HIPPOKAMPE_BROWSERS}" npm i -D playwright

echo
echo "Setting browsers file ${HIPPOKAMPE_GENERAL}/general.json"

create_browser_file() {
  browsers_file="$1"
  destination_file="$2"
  browsers_data="$(ls "${browsers_file}")"

  for i in $browsers_data ; do

      IFS='-'

      # shellcheck disable=SC2162
      read -a strarr <<< "$i"

      name="${strarr[0]}"
      version="${strarr[1]}"
      browsers+=("$name")
      versions+=("$version")

      case $name in
      chromium)
        path+=("/etc/hippokampe/browsers/$i/chrome-linux/chrome");;
      firefox)
        path+=("/etc/hippokampe/browsers/$i/firefox/firefox");;
      webkit)
        path+=("/etc/hippokampe/browsers/$i/minibrowser-gtk/bin/MiniBrowser");;
      esac

      unset IFS
  done

  result='{
  "browsers": ['
  for i in {0..2} ; do
    text=$(printf '{
      "name": "%s",
      "version": "%s",
      "path": "%s"
  }
  ' "${browsers[$i]}" "${versions[$i]}" "${path[$i]}")

    if [ "$i" != 2 ]; then
      text+=','
    fi

    result+="$text"
  done

  result+=']
  }'

  echo "$result" | jq .
  echo "$result" | jq . > "$destination_file"
}

create_browser_file "${HIPPOKAMPE_BROWSERS}" "${HIPPOKAMPE_GENERAL}/general.json"

# Hippokampe packages download
echo
echo "Downloading internal dependencies"

download_package "${HIPPOKAMPE_API}" "api"
download_package "${HIPPOKAMPE_CLI}" "hbtn"
download_package "${HIPPOKAMPE_DAEMON}" "hippokamped"

install_package "api hbtn hippokamped"

# Removing extra files
echo
echo "Removing extra files"
rm -rf "${DESTINATION}/api"
rm -rf "${DESTINATION}/hbtn"

echo
echo "Successfully installed"
