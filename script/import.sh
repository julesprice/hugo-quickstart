# Import podcast episodes from rss feeds
#!/usr/bin/env bash

# To help debugging....
#set -o xtrace
#clear

# .github/workflows/import.yaml calls ./.github/workflows/hugo.yaml if IMPORT_RESULT=PUSHED
export IMPORT_RESULT=UNDEFINED
# Recreate all files from scratch.  All existing episode .yaml an .md files are deleted before recreating
RECREATE=False
#RECREATE=True
# Commit and push changes?
#DEPLOY=False
DEPLOY=True

# Configure git
git config --global user.email "noreply@users.noreply.github.com"
git config --global user.name "import-workflow"
git config --global init.defaultBranch main

# Don't accidentally commit staged files
git diff --staged --quiet
if [ $? -ne 0 ]
then
    echo "ERROR: There are staged files"
    exit
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Import podcast episodes from rss feeds to yaml files
DATAPATH=$SCRIPT_DIR/../data/episode
if $RECREATE && ls $DATAPATH/*.yaml >/dev/null 2>&1
then
    echo "Removing existing .yaml files from $DATAPATH"
    rm $DATAPATH/*.yaml
fi

if $RECREATE
then
    YOUTUBE_PARAM='--youtubeapi=UUTUcatGD6xu4tAcxG-1D4Bg'
else
    YOUTUBE_PARAM='--youtuberss=https://www.youtube.com/feeds/videos.xml?channel_id=UCTUcatGD6xu4tAcxG-1D4Bg'
fi
python $SCRIPT_DIR/import.py \
    $YOUTUBE_PARAM \
    --spotify 'https://anchor.fm/s/822ba20/podcast/rss' \
    --output "$DATAPATH"
if [ $? -ne 0 ]
then
    echo "ERROR: Failed to import episodes"
    exit
fi

# Process yaml files into md files
SITEPATH=$SCRIPT_DIR/../content/episodes
if $RECREATE && ls SITEPATH/*.md >/dev/null 2>&1
then 
    echo "Removing existing .md files from $SITEPATH"
    rm $SITEPATH/*.md
fi
python $SCRIPT_DIR/createpages.py \
    --input "$DATAPATH" \
    --output "$SITEPATH"

if [ $? -ne 0 ]
then
    echo "ERROR: Failed to generate pages"
    exit
fi

if $DEPLOY
then
    # If there are changes then commit them
    git add "$DATAPATH"
    git add "$SITEPATH"
    if git diff --staged --quiet
    then
        echo "No changes"
        IMPORT_RESULT=NOCHANGES
    else
        echo "Committing and pushing changes"
        #echo "DEBUG-REMOTE"
        #git remote -v
        git commit -m "Import podcast episodes from rss feeds"
        git push
        #git remote -v
        IMPORT_RESULT=PUSHED
    fi
fi
