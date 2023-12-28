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
	x=$(cat -n $enc_shadow_path | cut -f1 | wc -l)
	return $x
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
	dec_pass=$(openssl pkeyutl -decrypt -inkey "$1.pem" -in "$2"_encrypted -out "$2"_decrypted.txt && cat "$2"_decrypted.txt)
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
			last_modified=$(echo $line | sed 's/.*::\([0-9]\{2\}-[0-9]\{2\}-[0-9]\{4\}:[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}\)::.*/\1/')
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
				echo "ID: $id | Key: $key | Last Modified: $last_modified"
			fi
		done < "$enc_shadow_path"
		read -p "Type your choice:" choice
		return $choice
	fi
}

function get(){
	multiple_key_choice $1
	choice=$?
	if [[ $choice -eq 0 ]]; then
		enc_pass=$(grep -E ":$1\\+" $enc_shadow_path | grep -Eo "\\+.*\\+" | sed '$ s/.$//' | sed 's/^.//')
	else
		enc_pass=$(grep -E "$choice:$1\\+" $enc_shadow_path | grep -Eo "\\+.*\\+" | sed '$ s/.$//' | sed 's/^.//')
	fi
	decrypt_pass "$private_key_location/$enc_pass" "$shadowed_password_location/$enc_pass"
	echo "Password: $dec_pass"
} 

function get_all(){
	count_lines
	total_lines=$?
	for ((x=1; x<=$total_lines; x++)); do
		key_name=$(sed -n "$x"p $enc_shadow_path | grep -Eo "\\:.*\\+" | sed '$ s/.$//' | sed 's/^.//')
		enc_pass=$(sed -n "$x"p $enc_shadow_path | grep -Eo "\\+.*\\+" | sed '$ s/.$//' | sed 's/^.//')
		last_modify=$(sed -n "$x"p $enc_shadow_path | grep -Eo "\\::.*\\::" | sed '$ s/.$//' | sed 's/^.//')
		decrypt_pass "$private_key_location/$enc_pass" "$shadowed_password_location/$enc_pass"
		echo "Key: $key_name | Password: $dec_pass | Last Modify: $last_modify"
	done
}

function save(){
	check_shadow_exits
	remove_empty_line
	hash_pass $2
	generate_private_key $hashed_pass
	generate_public_key $hashed_pass
	encrypt_pass $2
	readonly encrypted_pass=$?
	count_lines
	total_lines=$?
	incremented_line=$(echo "$total_lines + 1" | bc)
	echo "$incremented_line:$1+$hashed_pass+::$(fetch_current_date)::[$3]" >> $enc_shadow_path
}

function edit(){
	#TODO update time
	search_key=$1
	replace_key=$2
	replace_label=$3
	multiple_key_choice $search_key
	id="$?"
	if [[ $id -eq 0 ]]; then
		id=""
	fi
	function recreate_password(){
		hash_pass $1
		generate_private_key $hashed_pass
		generate_public_key $hashed_pass
		encrypt_pass $1
		readonly encrypted_repass=$?
	}
	recreate_password "$replace_key"
	current_date_and_time=$(fetch_current_date)
	sed_command_1="sudo sed -i -e '/$id:$search_key\\+/ { s/\\(\\+\\).*\\(\\+\\)/\\1$hashed_pass\\2/; s/\\(\\:\\:\\).*\\(\\:\\:\\)/\\1$current_date_and_time\\2/; "
	sed_command_3="' $enc_shadow_path"
	if [[ -n $replace_label ]]; then
		sed_command_2="s/\\(\\[\\).*\\(\\]\\)/\\1$replace_label\\2/;"
		sed_command="$sed_command_1$sed_command_2}$sed_command_3"
	else
		sed_command="$sed_command_1}$sed_command_3"
	fi
	eval "$sed_command"
}

function sort_id(){
	count_lines
	total_lines=$?
	for ((x=1; x<=$total_lines; x++)); do
		sed -n "$x"p $enc_shadow_path | sed -e s/^[^:]*:/$x:/ >> /tmp/pwm_temp 
	done
	sudo cp /tmp/pwm_temp $enc_shadow_path 
	sudo rm /tmp/pwm_temp
	return 0
}

function remove(){
	multiple_key_choice $1
	id="$?"
	if [[ $id -eq 0 ]]; then
		id=""
	fi
	sudo sed -i /$id:$1\\+/d $enc_shadow_path
	echo "ID: $id | Key: $1 has been removed successful!"
}

function help(){                    
	echo "pwm Password Manager Help Menu"
}

#main
if [[ $# -gt 0 ]]; then
	if [[ $1 == "--get" && -n $2 ]]; then
		get $2

	if [[ $1 == "--get-all" ]]; then
		getall

	elif [[ $1 == "--save" && -n $2 && -n $3 && -n $4 ]]; then
		save $2 $3 $4

	elif [[ $1 == "--edit" && -n $2 && -n $3 || -n $4 ]]; then
		edit $2 $3 $4

	elif [[ $1 == "--remove" && -n $2 ]]; then
		remove $2
		sort_id

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