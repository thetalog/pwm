#!/bin/bash

# pwm Password Manager

readonly enc_shadow_path="/etc/pwm/enc_shadow"
readonly private_key_location="/etc/pwm/private_keys"
readonly public_key_location="/etc/pwm/public_keys"
readonly shadowed_password_location="/etc/pwm/shadowed_passwords"

function check_shadow_exits(){
	if [[ -e "$enc_shadow_path" ]]; then
		return 0
	else
		sudo touch "$enc_shadow_path"
	fi
}	

function fetch_current_date(){
	date '+%d-%m-%Y:%H-%M-%S'
}

function count_lines(){
	cat -n $enc_shadow_path | cut -f1 | wc -l
}

function remove_empty_line(){
	sed -i '/^$/d' $enc_shadow_path
	if [[ $? -eq 0 ]]; then
		return 0
	else
		echo "Something went wrong!"
	fi
}

function detect_multiple_key(){
	# $1 --> key
	count=$(grep -E ":$1+" $enc_shadow_path | wc -l)
    result=$(python3 -c "count = $count; print(1) if count > 1 else print(0)") #return 1 for multiple detection or 0 for 1 or none
	return $result
}

function check_or_create_directory(){
	if [[ -e $1 ]]; then
		return 0
	else
		sudo mkdir $1 > /dev/null 2>&1
		if [[ $? -eq 0 ]]; then
			return 0
		else
			return 1
		fi
	fi
}

# remove sudo from everywhere
function generate_private_key(){
	# $1 -> hashed_pass
	check_or_create_directory $private_key_location
	if [[ $? -eq 0 ]]; then
		openssl genrsa -out "$private_key_location/$1.pem" 2048
		if [[ $? -eq 0 ]]; then
			generated_private_key_location="$private_key_location/$1.pem"
			return 0
		else
			return 1
		fi
	else
		return 1
	fi
}

function generate_public_key(){
	# $1 -> hashed_pass
	check_or_create_directory $public_key_location
	if [[ $? -eq 0 ]]; then
		openssl rsa -pubout -in "$private_key_location/$1.pem" -out "$public_key_location/$1.pem" > /dev/null 2>&1
		if [[ $? -eq 0 ]]; then
			generated_public_key_location="$public_key_location/$1.pem"
			return 0
		else
			return 1
		fi
	else 
		return 1
	fi
}

function encrypt_pass(){
	# $1 -> plain_text e.g. password
	check_or_create_directory $shadowed_password_location
	if [[ $? -eq 0 ]]; then
		echo "$1" | openssl pkeyutl -encrypt -inkey "$generated_public_key_location" -pubin -out "$shadowed_password_location/$hashed_pass"_encrypted
		if [[ $? -eq 0 ]]; then
			return 0
		else
			return 1
		fi
	else 
		return 1
	fi
}

function decrypt_pass(){
	# $1 -> private_key
	# $2 -> encrypted_text
	dec_pass=$(openssl pkeyutl -decrypt -inkey "$1.pem" -in "$2"_encrypted -out "$2"_decrypted.txt | cat "$2"_decrypted.txt)
	# rm ./"$2"_decrypted.text
	if [[ $? -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}

function hash_pass(){
	hashed_pass=$(echo "$1" | openssl md5 -hex | tr -d ' ' | tail -c 17)
	if [[ -n "$hash" && ! "$hash" =~ "error" ]]; then
	    return 0
	else
		return 1
	fi
}

function check_exist_return_key_location(){
	local location;
	if [[ $1 == "public" ]]; then
		location="$public_key_location/$1"
	elif [[ $1 == "private" ]]; then
		location="$private_key_location/$1"
	fi
	if [[ -e $location ]]; then
		return "$location"
	else 
		return 1
	fi
}

function save_keys(){
	local location;
	if [[ $1 == "public" ]]; then
		location="$public_key_location/$1"
	elif [[ $1 == "private" ]]; then
		location="$private_key_location/$1"
	fi
	if [[ -e $location ]]; then
		return 1
	else 
		sudo touch $location
		if [[ $? -eq 0 ]]; then 
			return "$location"
		else
			return 1
		fi
	fi
}

function multiple_key_choice(){
	detect_multiple_key "$1"
	if [[ $? -eq 0 ]]; then
        	return 0
	else
		echo "Multiple keys detected, select by ID."
		while IFS=: read -r line; do
			id=$(echo $line | sed 's/\([^:]*\):.*/\1/')
			key=$(echo $line | sed 's/[^:]*:\([^+]*\)+.*/\1/')
			if [[ -n $id ]]; then
				if [[ $id -lt 10 ]]; then
					id="0$id"
				else
					id=$id
				fi
			else
				id="NA"
			fi
			if [[ $1 == $key ]]; then
				echo "ID: $id | Key: $key"
			fi
		done < "$enc_shadow_path"
		read -p "Type your choice:" choice
		return $choice
	fi
}

function get(){
	multiple_key_choice $1
	enc_pass=$(grep -E "$?:$1\\+" $enc_shadow_path | grep -Eo "\\+.*\\+" | sed '$ s/.$//' | sed 's/^.//')
	decrypt_pass $private_key_location/$enc_pass $shadowed_password_location/$enc_pass
	echo "$dec_pass"
} 

function save(){
	check_shadow_exits
	remove_empty_line
	hash_pass $2
	generate_private_key $hashed_pass
	generate_public_key $hashed_pass
	encrypt_pass $2
	readonly encrypted_pass=$?
	incremented_line=$(echo "$(count_lines) + 1" | bc)
	echo "$incremented_line:$1+$hashed_pass+::$(fetch_current_date)::[$3]" >> $enc_shadow_path
}

function edit(){
	#TODO update time
	search_key=$2
	replace_key=$3
	replace_label=$4
	multiple_key_choice $search_key
	id="$?"
	if [[ $id -eq 0 ]]; then
		id=""
	fi
	sed_command_1="sudo sed -i -e '/$id:$search_key\\+/ { s/\\(\\+\\).*\\(\\+\\)/\\1$replace_key\\2/;"
	sed_command_3="' $enc_shadow_path"
	if [[ -n $replace_key ]]; then
		sed_command_2="s/\\(\\[\\).*\\(\\]\\)/\\1$replace_label\\2/; }"
		sed_command="$sed_command_1$sed_command_2$sed_command_3"
		echo "$sed_command"
	fi
	eval "$sed_command"
}

function help(){
	echo "pwm Password Manager Help Menu"
}


#main
if [[ $# -gt 0 ]]; then
	if [[ $1 == "--get" && -n $2 ]]; then
		get $2

	elif [[ $1 == "--save" && -n $2 && -n $3 && -n $4 ]]; then
		save $2 $3 $4

	elif [[ $1 == "--edit" && -n $2 && -n $3 && -n $4 ]]; then
		edit

	elif [[ $1 == "--help" ]]; then
		help

	else
		echo "Wrong Argument: check 'pwm --help'"
		exit 0
	fi
else
	echo "Argument Error: pwm <argument>"
	echo "Wrong Argument: check 'pwm --help'"
	exit 0
fi
