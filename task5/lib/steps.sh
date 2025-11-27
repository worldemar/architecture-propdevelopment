step() {
  local message="$1"; shift
  echo -ne "[\e[36m....\e[0m] ${message}"
  if output=$("$@" 2>&1); then
    echo -e "\r[ \e[32mOK\e[0m ] ${message}"
  else
    echo -e "\r[\e[31mFAIL\e[0m] ${message}"
    echo "${output}"
    exit 1
  fi
}
