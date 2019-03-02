
import sys
import os
import requests
import re
import subprocess

platforms = ["linux", "macos", "win"]

if sys.platform == "darwin":
	md5sum_cmd = ["md5", "-r"]
else:
	md5sum_cmd = ["md5sum"]

makefile_path = os.path.join(os.path.dirname(sys.argv[0]), "..", "Makefile")

print("Fetching latest release")
json = requests.get("https://api.github.com/repos/radareorg/cutter-deps-qt/releases/latest").json()

release_url = json["assets"][0]["browser_download_url"]
for platform in platforms:
	release_url = release_url.replace(platform, "${PLATFORM}")

print(f"Using URL {release_url}")

with open(makefile_path) as f:
	makefile = f.read()

md5 = {}
for platform in platforms:
	platform_url = release_url.replace("${PLATFORM}", platform)
	print(f"Getting MD5 for {platform_url}")

	curl = subprocess.Popen(["curl", "-fL", platform_url], stdout=subprocess.PIPE)
	md5sum = subprocess.run(md5sum_cmd, stdin=curl.stdout, capture_output=True, encoding="utf-8").stdout
	curl.wait()
	if curl.returncode != 0:
		print(f"Failed to download {platform_url}, skipping.")
		continue

	md5sum = re.fullmatch("([a-zA-Z0-9]+)( -)?\n?", md5sum).group(1)

	print(f"MD5: {md5sum}")
	makefile = re.sub(f"^QT_BIN_MD5_{platform}.*$", f"QT_BIN_MD5_{platform}={md5sum}".replace("\\", r"\\"), makefile, flags=re.MULTILINE)

makefile = re.sub("^QT_BIN_URL=.*$", f"QT_BIN_URL={release_url}".replace("\\", r"\\"), makefile, flags=re.MULTILINE)

with open(makefile_path, "w") as f:
	f.write(makefile)
