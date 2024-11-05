#!/bin/sh

set -e
set -x

if [ -z "$INPUT_SOURCE_FILE" ]
then
  echo "Source file must be defined"
  return 1
fi

if [ -z "$INPUT_GIT_SERVER" ]
then
  INPUT_GIT_SERVER="github.com"
fi

if [ ! -z "$INPUT_DESTINATION_BRANCH" ]
then
  echo "Input branch has been set as destination"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"
else
  echo "Please add a destination branch to action config"
fi

git config --global --add safe.directory /github/workspace
git config --global user.email "$INPUT_USER_EMAIL"
git config --global user.name "$INPUT_USER_NAME"

CLONE_DIR=$(mktemp -d)

BRANCH_EXISTS=$(git ls-remote --heads "https://x-access-token:$API_TOKEN_GITHUB@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$INPUT_DESTINATION_BRANCH")
BRANCH_EXISTS_TWO=$(git ls-remote --heads "https://$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$INPUT_DESTINATION_BRANCH")

if [ -n "$BRANCH_EXISTS" ]; then
  echo "BRANCH EXISTS"
else
  echo "BRANCH NOT EXISTS"
fi

if [ -n "$BRANCH_EXISTS_TWO" ]; then
  echo "BRANCH EXISTS TWO"
else
  echo "BRANCH NOT EXISTS TWO"
fi

git clone --single-branch --branch main "https://x-access-token:$API_TOKEN_GITHUB@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
cd "$CLONE_DIR"
git fetch origin

if [ -z `git branch --list $OUTPUT_BRANCH` ]
then
  echo "Branch found - checkout output branch"
  git checkout -b "$OUTPUT_BRANCH" origin/"$OUTPUT_BRANCH"
else
  echo "Not Branch found - creating new branch: ${INPUT_DESTINATION_BRANCH}"
  git checkout -b "$INPUT_DESTINATION_BRANCH"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"
fi

cd "../"


if [ ! -z "$INPUT_RENAME" ]
then
  echo "Setting new filename: ${INPUT_RENAME}"
  DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER/$INPUT_RENAME"
else
  DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
fi

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER
if [ -z "$INPUT_USE_RSYNC" ]
then
  cp -R "$INPUT_SOURCE_FILE" "$DEST_COPY"
else
  echo "rsync mode detected"
  rsync -avrh "$INPUT_SOURCE_FILE" "$DEST_COPY"
fi

cd "$CLONE_DIR"



if [ -z "$INPUT_COMMIT_MESSAGE" ]
then
  INPUT_COMMIT_MESSAGE="Update from $INPUT_USER_ACTOR from this repository https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
fi

echo "Adding git commit"
git add .
if git status | grep -q "Changes to be committed"
then
  git commit --message "$INPUT_COMMIT_MESSAGE"
  echo "Pushing git commit"
  git push -u origin HEAD:"$OUTPUT_BRANCH"
else
  echo "No changes detected"
fi
