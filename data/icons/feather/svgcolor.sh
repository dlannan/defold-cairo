#/bin/bash
name=$1
COLOR=white
if [[ -n "$name" ]]; then 
	COLOR=$name
fi
cp -rf backup/*.svg .
sed -i "s/currentColor/"$COLOR"/g" *.svg
