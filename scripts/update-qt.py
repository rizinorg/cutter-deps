
import sys
import os
import requests
import re
import subprocess

makefile_path = os.path.join(os.path.dirname(sys.argv[0]), "..", "Makefile")

print("Fetching latest release")
json = requests.get("https://api.github.com/repos/radareorg/cutter-deps-qt/releases/latest").json()

release_url = json["assets"][0]["browser_download_url"]

print(f"Getting MD5 for {release_url}")

curl = subprocess.Popen(["curl", "-L", release_url], stdout=subprocess.PIPE)
md5sum = subprocess.run(["md5sum"], stdin=curl.stdout, capture_output=True, encoding="utf-8").stdout
curl.wait()

md5sum = re.match("([a-zA-Z0-9]+) ", md5sum).group(1)

print(f"MD5: {md5sum}")

with open(makefile_path) as f:
	makefile = f.read()

makefile = re.sub("^QT_BIN_URL=.*$", f"QT_BIN_URL={release_url}".replace("\\", r"\\"), makefile, flags=re.MULTILINE)
makefile = re.sub("^QT_BIN_MD5=.*$", f"QT_BIN_MD5={md5sum}".replace("\\", r"\\"), makefile, flags=re.MULTILINE)

with open(makefile_path, "w") as f:
	f.write(makefile)
