import subprocess
from datetime import date
import os
import sys
import re

print("### push release to github")
target_fp = "app-release.apk"
assert os.path.isfile(target_fp)
version = None
with open("pubspec.yaml", "r") as f:
    ps = f.read()
    version = re.findall("version: ([\d|.]+)", ps)[0]
    print("version:", version)
    assert version
cmd = "gh release create v{} {}".format(version, target_fp)
print("push to github cmd:")
print(cmd)
ret = os.system(cmd)
assert ret == 0
print("pushed to {} url:".format(target_fp))
print("https://github.com/ykasidit/bluetooth_gnss/releases")
