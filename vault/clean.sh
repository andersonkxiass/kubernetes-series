#!/bin/bash


helm -n hashcorp uninstall consul vault

kubectl -n hashcorp delete pvc --all

kubectl delete sa postgres-vault