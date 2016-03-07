#!/bin/bash

clear

plugin_dir=svencoop_addon/scripts/plugins
combo_res_file=_combined_resources_list.txt
map_dirs="svencoop/maps svencoop_addon/maps svencoop_downloads/maps"
cwd=$(pwd)

if [ ! -d "svencoop" ] || [ ! -d "svencoop_addon" ]; then
	echo This script needs to be placed in your Sven Co-op folder.
	echo Move it there and try again.
	echo.
	read -p "Press Enter to continue..." key
	exit
fi



while true; do
	cd "$cwd"
	clear
	echo  Welcome to the AngelScript Resource Manager
	echo ""
	PS3='
Please enter your choice: '
	options=("Update" "Restore" "Quit")
	select opt in "${options[@]}"
	do
		case $opt in
			"Update")
				clear		
				#
				# Verify that resource lists exist
				#
				
				if [ ! -d "$plugin_dir/resources" ]; then
					mkdir -p $plugin_dir/resources
				fi
				cd $plugin_dir
				cd resources
				
				# Erase the combined resources file if it exists
				if [ -f "$combo_res_file" ]; then
					rm $combo_res_file
				fi
				
				# Count the files in the resource folder
				cnt=$(ls -1 *.res | wc -l)
				
				if [ $cnt == 0 ]; then
					echo Your plugin resources folder is empty!
					echo
					echo Place your resource lists in this folder and try again:
					echo svencoop_addon/scripts/plugins/resources
					echo
					echo Make sure your lists have the \".res\" file extension.
					echo
					read -p "Press Enter to continue..." key
					break
				fi

				# Combine into one list
				for f in *.res; do
					cat $f >> $combo_res_file
					printf "\n" >> $combo_res_file
				done

				lines=$(wc -l $combo_res_file | cut -d " " -f1)

				echo Found approximately $lines resources in $cnt lists.

				cd "$cwd"

				cnt=0
				for dir in $map_dirs; do
					if [ -d "$dir" ]; then
						nummaps=$( ls -1 $dir/*.bsp | wc -l )
						cnt=$(( cnt + nummaps))
					else
						echo Warning: \"$dir\" does not exist
					fi
				done

				echo
				echo $cnt map .res files will be modified/created. 
				echo If a map does not have a .res file, one will be created for it.
				echo
				read -p "Press Enter to continue..." key
				echo
				echo Hold onto your butts...
				echo

				num_updates=0
				num_creates=0
				for d in $map_dirs; do
					cd "$cwd"
					if [ -d "$d" ]; then
						cd $d
						for map in *.bsp; do
							name="${map%%.*}"

							if [ -f "$name.res" ]; then
								# Update existing res file
								echo Updating $d/$name.res
								if [ -f "$name.res.bak" ]; then
									# Restore original contents before patching
									rm -- "$name.res"
									cp -- "$name.res.bak" "$name.res" >NUL
								else
									# Make a backup of the existing res file
									cp -- "$name.res" "$name.res.bak" >NUL
								fi
								num_updates=$(( num_updates + 1 ))
							else
								echo Creating $d/$name.res
								# Create an empty res file for this map
								touch -- "$name.res"
								# Create an empty backup too so we don't back up plugin resources on the next run
								touch -- "$name.res.bak"
								num_creates=$(( num_creates+ 1 ))
							fi
							
							# Patch the res file
							printf "\n\n" >> "$name.res"
							echo "// The following files are used by AngelScript server plugins." >> $name.res
							printf "\n" >> "$name.res"
							cat ../../$plugin_dir/resources/$combo_res_file >> $name.res
						done
					fi
				done
				echo
				echo $num_updates .res files were updated
				echo $num_creates .res files were created
				echo

				read -p "Press Enter to continue..." key
				break
				;;
			"Restore")
				clear
				echo Maps with a .res.bak file will have their .res file restored.
				echo Maps that did not originally have a .res file will have it deleted.
				echo
				read -p "Press Enter to continue..." key

				num_restores=0
				num_not_exist=0
				num_deleted=0

				for d in $map_dirs; do
					cd "$cwd"
					if [ -d "$d" ]; then
						cd $d
						for map in *.bsp; do
							name="${map%%.*}"
							if [ -f "$name.res.bak" ]; then
								len=$(cat -- "$name.res.bak" | wc -l | cut -d " " -f1)
								
								if [ "$len" != "0" ]; then
									# Restore original contents
									echo Restoring $d/$name.res
									rm -- "$name.res"
									cp -- "$name.res.bak" "$name.res"
									rm -- "$name.res.bak"
									num_restores=$(( num_restores + 1 ))
								else
									# Res file backup was empty. Delete it and the current .res
									echo Deleting  $d/$name.res
									rm -- "$name.res.bak"			
									rm -- "$name.res"
									num_deleted=$(( num_deleted + 1 ))
								fi
							else
								# Backup didn't exist. Hopefully no one deleted it accidently.
								num_not_exist=$(( num_not_exist + 1 ))
							fi
						done
					fi
				done

				echo
				echo $num_restores .res files were restored
				echo $num_deleted empty .res files were deleted
				echo $num_not_exist maps had no .res file backup
				echo

				read -p "Press Enter to continue..." key
				break
				;;
			"Quit")
				exit
				;;
		        *) echo invalid option;;
	    	esac
	done
done

read -p "Press Enter to continue..." key
exit

:restore_res





cd %cwd%
pause
goto start