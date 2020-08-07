#!/bin/bash
cd /data/data || exit
rm -r ./*/app_tbs/*
rm -r ./*/app_tbs_64/*
chattr -i ./*/app_tbs
chattr -i ./*/app_tbs_64
chmod 000 ./*/app_tbs
chmod 000 ./*/app_tbs_64
