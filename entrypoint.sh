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

echo "$INPUT_DESTINATION_BRANCH_EXISTS"

if [ $INPUT_DESTINATION_BRANCH_EXISTS -eq "false" ]
then
  echo "Creating new branch: ${INPUT_DESTINATION_BRANCH}"
  git clone --single-branch --branch main "https://x-access-token:$API_TOKEN_GITHUB@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
  git checkout -b "$INPUT_DESTINATION_BRANCH"
  OUTPUT_BRANCH="$INPUT_DESTINATION_BRANCH"
else
  echo "Cloning destination git repository"
  git clone --single-branch --branch $OUTPUT_BRANCH "https://x-access-token:$API_TOKEN_GITHUB@$INPUT_GIT_SERVER/$INPUT_DESTINATION_REPO.git" "$CLONE_DIR"
fi


if [ ! -z "$INPUT_RENAME" ]
then
  echo "Setting new filename: ${INPUT_RENAME}"
  DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER/$INPUT_RENAME"
else
  DEST_COPY="$CLONE_DIR/$INPUT_DESTINATION_FOLDER"
fi

echo "starting CLONE_DIR: $CLONE_DIR"
tree "$CLONE_DIR"

echo "Wiping destination folder"
rm -rf "$CLONE_DIR/$INPUT_DESTINATION_FOLDER/*"

echo "next CLONE_DIR: $CLONE_DIR"
tree "$CLONE_DIR"

echo "Copying contents to git repo"
mkdir -p $CLONE_DIR/$INPUT_DESTINATION_FOLDER
echo "next next CLONE_DIR: $CLONE_DIR"
tree "$CLONE_DIR"
if [ -z "$INPUT_USE_RSYNC" ]
then
  cp -R "$INPUT_SOURCE_FILE" "$DEST_COPY"
else
  echo "rsync mode detected"
  rsync -avrh "$INPUT_SOURCE_FILE" "$DEST_COPY"
fi
echo "next next next CLONE_DIR: $CLONE_DIR"

cd "$CLONE_DIR"

if [ -z "$INPUT_COMMIT_MESSAGE" ]
then
  INPUT_COMMIT_MESSAGE="Update from $INPUT_USER_ACTOR from this repository https://$INPUT_GIT_SERVER/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}"
fi

echo "Adding git commit"
git add -A
if git status | grep -q "Changes to be committed"
then
  git commit --message "$INPUT_COMMIT_MESSAGE"
  echo "Pushing git commit"
  git push -u origin HEAD:"$OUTPUT_BRANCH"
else
  echo "No changes detected"
fi
