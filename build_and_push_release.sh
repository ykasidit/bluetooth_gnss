#!/bin/bash
rm -f app-release.apk ; flutter clean ; ./build.sh && ./push_release.sh
