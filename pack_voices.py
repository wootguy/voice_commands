import os, sys, subprocess, shutil, base64, re

gap = 0.2   # seconds of silence between sounds
gap_fname = 'gap.wav'
temp_dir = 'temp'
quiet = True

g_default_sentence_sounds = None

# needed for shortest possible file names to prevent 8k char limit in command line
def base36encode(number, alphabet='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'):
    base36 = ''

    if 0 <= number < len(alphabet):
        return alphabet[number]

    while number != 0:
        number, i = divmod(number, len(alphabet))
        base36 = alphabet[i] + base36

    return base36
	
def getDefaultSentenceSounds():
	global g_default_sentence_sounds
	
	g_default_sentence_sounds = set()
	file = open("default_sentences.txt", 'r', encoding='ansi')
	
	for line in file.readlines():
		line.strip()
		
		if len(line) == 0 or line.find("//") == 0:
			continue;
		
		old_line = line
		line = re.sub('\([\w\s]+\)', '', line)
		line = line.replace(".", " ")
		line = line.replace(",", " ")
		
		parts = line.split(" ")
		if len(parts) > 1:
			folder = parts[1][:parts[1].find("/")+1]
		
			for sound in parts[2:]:			
				if '/' in sound:
					sound = sound[:sound.find('/')]
				
				pidx = sound.find("(")
				pidx2 = sound.find(")")
				
				if pidx != -1:
					sound = sound[pidx]
					pidx2 = sound.find(")")
					
					if pidx2 < int(len(sound)) and pidx2 != -1:
						sound = sound[pidx2+1:]
				elif pidx2 != -1:
					sound = "" # space separated modifiers included in the split. No sound path here.

				if len(sound) != 0:
					sound = folder + sound;
					ext = ".ogg" if parts[1].find("bodyguard") != -1 else ".wav"
					soundFile = sound + ext
					g_default_sentence_sounds.add(soundFile.lower())
	
	print("Loaded %s default sentence sounds" % len(g_default_sentence_sounds))

getDefaultSentenceSounds()

if os.path.exists(gap_fname):
	os.remove(gap_fname)

if not os.path.exists(temp_dir):
	os.makedirs(temp_dir)
	
os.chdir(temp_dir)

os.system('ffmpeg -f lavfi -t %s -i anullsrc=cl=mono -y -f wav %s' % (gap, gap_fname))

for voice in os.listdir('../voices'):
	voicePath = os.path.join('../voices', voice)
	
	if os.path.isdir(voicePath) or '.pack' in voice:
		continue
	
	file = open(voicePath, 'r', encoding='utf-8')
	safe_voice = os.path.splitext(voice)[0].lower().replace(" ", "_")

	if 'Rushia' not in voice:
		continue

	print("PACK VOICE: " + voice)
	
	all_sounds = []
	unique_sounds = set()
	
	for line in file.readlines():
		if '//' in line:
			line = line[:line.find('//')]
			
		line = line.strip()
		
		if not line:
			continue
		
		parts = line.split(":")
		if len(parts) < 2:
			continue

		sound = parts[1].strip()
		if len(sound) < 1 or sound[0] == '!':
			continue
		
		if sound.lower() not in g_default_sentence_sounds and sound.lower() not in unique_sounds:
			all_sounds.append(sound)
			unique_sounds.add(sound.lower())
	
	if len(all_sounds) <= 4:
		print("Skipping voice with 4 or less sounds")
		continue
	
	args = ''
	offsetsFile = open(os.path.splitext(voice)[0] + ".pack", "w")
	offsetsFile.write("vc/pack/%s_v1.wav\n" % safe_voice)
	offset = 0
	temp_files = []

	for idx, sound in enumerate(all_sounds):
		path = ''
		
		tryPaths = [
			'../sound',
			'../../../../../svencoop_addon/sound',
			'../../../../../svencoop/sound',
			'../../../../../svencoop_downloads/sound'
		]
		
		for tryPath in tryPaths:
			if (os.path.exists(os.path.join(tryPath, sound))):
				path = os.path.join(tryPath, sound).replace('\\', '/')
				new_path = base36encode(idx)
				
				if os.path.exists(new_path):
					os.remove(new_path)
				
				shutil.copy(path, new_path)
				path = new_path
				temp_files.append(path)
				break
		
		if not path:
			print("Failed to find file: " + sound)
			sys.exit()
		
		args += ' -i %s' % path
		
		cmd = ['ffprobe', '-i', path, '-show_entries', 'format=duration', '-v', 'quiet', '-of', 'csv=p=0']
		duration = float(subprocess.check_output(cmd).decode('utf-8').strip())
		print("%.6f : %.6f : %s" % (offset, duration, sound))
		offsetsFile.write("%.6f : %.6f : %s\n" % (offset, duration,  sound))
		offset += duration + gap
		
		# add a gap to the file
		cmd = 'ffmpeg -i %s -i %s -filter_complex concat=n=2:v=0:a=1[out] -map [out] -c:a pcm_u8 -f wav %s -y temp.wav' % (path, gap_fname, '-v quiet' if quiet else '')
		os.system(cmd)
		os.remove(path)
		os.rename('temp.wav', path)
	
	offsetsFile.close()
	
	filter = 'concat=n=%d:v=0:a=1[out]' % (len(all_sounds))
	
	output_file = "%s_v1.wav" % safe_voice
	
	print("Writing %s" % output_file)
	#codec = '-c:a adpcm_ima_wav' # pcm_u8
	codec = '-c:a pcm_u8 -ac 1 -ar 22050'
	cmd = "ffmpeg %s -filter_complex %s -map [out] %s -y %s" % (args, filter, codec, output_file)
	os.system(cmd)
	print(cmd)
	
	for f in temp_files:
		if os.path.exists(f):
			os.remove(f)

os.remove(gap_fname)