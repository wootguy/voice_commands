echo off
cls

TITLE AngelScript Resource Manager v2
setlocal enabledelayedexpansion

set plugin_dir=svencoop_addon\scripts\plugins
set combo_res_file=_combined_resources_list.txt
set map_dirs=svencoop\maps svencoop_addon\maps svencoop_downloads\maps
set cwd=%CD%

if exist svencoop if exist svencoop_addon goto start
echo This batch file needs to be placed in your "Sven Co-op" folder.
echo Move it there and try again.
echo.
pause
exit

:start
cls
echo.
echo Select an action:
echo.
echo 1) Update - run this after installing a plugin or adding new maps
echo.
echo 2) Restore - choose this to get your original map .res files back

choice /c 12 /n
IF %errorlevel%==1 goto update_res
IF %errorlevel%==2 goto restore_res

:update_res
cls

::
:: Verify that resource lists exist
::

if not exist %plugin_dir%\resources (
	md %plugin_dir%\resources
)
cd %plugin_dir%\resources

:: Erase the combined resources file if it exists
if exist %combo_res_file% (
	del %combo_res_file%
)

:: Count the files in the resource folder
set cnt=0
for %%A in (*.res) do set /a cnt+=1

if %cnt% == 0 (
	echo Your plugin resources folder is empty!
	echo.
	echo Place your resource lists in this folder and try again:
	echo %plugin_dir%\resources
	echo.
	echo Make sure your lists have the ".res" file extension.
	echo.
	pause
	goto start
)

for %%A in (*.res) do (
	type %%A >> %combo_res_file%
	echo. >> %combo_res_file%
)

:: Count the lines in the file
for /f  %%a in (%combo_res_file%) do (set /a Lines+=1)

echo Found approximately %Lines% resources in %cnt% lists.
echo.

cd %cwd%

set cnt=0
for %%d in (%map_dirs%) do (
	if exist %%d (
		cd %%d
		for %%A in (*.bsp) do set /a cnt+=1
		cd "%cwd%"
	) else (
		echo Warning: %%d does not exist
	)
)

echo %cnt% map .res files will be modified/created. 
echo If a map does not have a .res file, one will be created for it.
echo.
pause
echo.
echo Hold onto your butts...
echo.

::
:: Begin the patching
::

set num_updates=0
set num_creates=0
for %%d in (%map_dirs%) do (
	cd "%cwd%"
	if exist %%d (
		cd %%d
		for %%A in (*.bsp) do (
			if exist %%~nA.res (
				rem Update existing res file
				echo Updating %%d\%%~nA.res
				if exist %%~nA.res.bak (
					rem Restore original contents before patching
					del %%~nA.res
					copy %%~nA.res.bak %%~nA.res >NUL
				) else (
					rem Make a backup of the existing res file
					copy %%~nA.res %%~nA.res.bak >NUL
				)
				set /a num_updates+=1
			) else (
				echo Creating %%d\%%~nA.res
				rem Create an empty res file for this map
				copy /y NUL %%~nA.res >NUL
				rem Create an empty backup too so we don't back up plugin resources on the next run
				copy /y NUL %%~nA.res.bak >NUL
				set /a num_creates+=1
			)
			
			rem Patch the res file
			echo. >> %%~nA.res
			echo. >> %%~nA.res
			echo // The following files are used by AngelScript server plugins, not the map. >> %%~nA.res
			echo. >> %%~nA.res
			type ..\..\%plugin_dir%\resources\%combo_res_file% >> %%~nA.res
		)
	)
)
echo.
echo %num_updates% .res files were updated
echo %num_creates% .res files were created
echo.
echo Remember to run this again when you install new maps.
echo.

cd %cwd%
pause
goto start




:restore_res

cls
echo Maps with a .res.bak file will have their .res file restored.
echo Maps that did not originally have a .res file will have it deleted.
echo.
pause

set num_restores=0
set num_not_exist=0
set num_deleted=0

for %%d in (%map_dirs%) do (
	cd "%cwd%"
	if exist %%d (
		cd %%d
		for %%A in (*.bsp) do (
			if exist %%~nA.res.bak (
				set len=0
				for /f  %%a in (%%~nA.res.bak) do (set /a len+=1)
				
				if !len! GTR 0 (
					rem Restore original contents if the backup isn't empty
					echo Restoring %%d\%%~nA.res
					del %%~nA.res
					copy %%~nA.res.bak %%~nA.res >NUL
					del %%~nA.res.bak
					set /a num_restores+=1
				) else (
					rem Res file backup was empty. Delete it and the current .res
					echo Deleting  %%d\%%~nA.res
					del %%~nA.res.bak				
					del %%~nA.res
					set /a num_deleted+=1
				)
			) else (
				rem Backup didn't exist. Hopefully no one deleted it accidently.
				set /a num_not_exist+=1
			)
		)
	)
)
echo.
echo %num_restores% .res files were restored
echo %num_deleted% empty .res files were deleted
echo %num_not_exist% maps had no .res file backup
echo.

cd %cwd%
pause
goto start