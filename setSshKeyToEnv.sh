#!/bin/bash

SSH_KEY=$(cat ~/.ssh/github_rsa | base64 --wrap=0)

export TF_VAR_SSH_PRIVATE_KEY=$(echo $SSH_KEY)

bash