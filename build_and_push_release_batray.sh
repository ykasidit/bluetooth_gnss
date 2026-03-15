#!/bin/bash
rm -f app-batray-release.apk ; flutter clean ; ./build_batray.sh && ./push_release.sh
