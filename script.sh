 #!/bin/bash
 set -eo pipefail
 
 echo -e "machine github.com\n  login $GITHUB_TOKEN" > ~/.netrc
 echo -e "Installing dependencies.......\n"
 
 apt-get -y update && \
 apt-get -y upgrade && \
 apt-get install --no-install-recommends -y \
            zip \
            unzip \
            bc \
            bison \
            build-essential \
            curl \
            flex \
            g++-multilib \
            gcc \
            gcc-multilib \
            clang \
            git \
            gnupg \
            gperf \
            imagemagick \
            lib32ncurses5-dev \
            lib32readline-dev \
            lib32z1-dev \
            liblz4-tool \
            libncurses5-dev \
            libsdl1.2-dev \
            libwxgtk3.0-dev \
            libxml2 \
            libxml2-utils \
            lzop \
            pngcrush \
            schedtool \
            squashfs-tools \
            xsltproc \
            zlib1g-dev \
            openjdk-8-jdk \
            python \
            ccache \
            libtinfo5 \
            repo \
            libstdc++6\
            wget \
            libssl-dev \
            rsync \
            golang-go
            
apt-get update && apt-get install -y libssl-dev libssl1.0.0

echo -e "sanity checks.....\n" \

if [[ -z $GIT_EMAIL ]]; then echo -e "You haven't configured GitHub E-Mail Address." && exit 1; fi
if [[ -z $GIT_NAME ]]; then echo -e "You haven't configured GitHub Username." && exit 1; fi
if [[ -z $DEVICE ]]; then echo -e "You haven't configured your device name." && exit 1; fi
if [[ -z $VENDOR ]]; then echo -e "You haven't configured your vendor name." && exit 1; fi
if [[ -z $FLAVOR ]]; then echo -e "Set up your lunch flavor for ex.lunch omni_rmx1925-eng here 'eng' is flavor ." && exit 1; fi
if [[ -z $REC_BRANCH ]]; then echo -e "set recovery branch name." && exit 1; fi

echo -e "initializing variables..." \
     -e GitHubMail="${GIT_EMAIL}" -e GitHubName="${GIT_NAME}" -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
     -e DEVICE="${DEVICE}" -e VENDOR="${VENDOR}" -e REC_BRANCH="${REC_BRANCH}"
echo -e "done......\n" \
     
echo -e "setting up.......\n" \ 
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH

git config --global color.ui false 

[[ ! -d /tmp ]] && mkdir -p /tmp
#Make a keepalive shell so that it can bypass CI Termination on output freeze
cat << EOF > /tmp/keepalive.sh
#!/bin/bash
echo \$$ > /tmp/keepalive.pid # keep this so that it can be killed from other command
while true; do
 echo "." && sleep 300
done
EOF
chmod a+x /tmp/keepalive.sh

echo -e "going to default directory...\n"
cd ~ && DIR=$(pwd)
mkdir $(pwd)/shrp && cd shrp

# randomize and fix sync thread number, according to available cpu thread count

SYNCTHREAD=$(grep -c ^processor /proc/cpuinfo)          # Default CPU Thread Count

if [[ $(echo ${SYNCTHREAD}) -le 2 ]]; then SYNCTHREAD=$(shuf -i 5-7 -n 1)        # If CPU Thread >= 2, Sync Thread 5~7

elif [[ $(echo ${SYNCTHREAD}) -le 8 ]]; then SYNCTHREAD=$(shuf -i 12-16 -n 1)    # If CPU Thread >= 8, Sync Thread 12~16

elif [[ $(echo ${SYNCTHREAD}) -le 36 ]]; then SYNCTHREAD=$(shuf -i 30-36 -n 1)   # If CPU Thread >= 36, Sync Thread 30~36

fi

# sync
echo -e "Initializing and syncing SHRP repo...\n" \

repo init -u git://github.com/SHRP/manifest.git -b v3_11.0
/tmp/keepalive.sh & repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags
kill -s SIGTERM $(cat /tmp/keepalive.pid)

echo -e "syncing done succesfully......\n"

echo -e "\n cloning device tree and kernel tree on right place.....\n"
git clone https://github.com/eun0115/android-recovery_device-r5x device/realme/${DEVICE}
git clone --depth 1 https://github.com/KharaMe-devices/kernel_realme_r5x kernel/realme/${DEVICE}

echo -e "setting up envernment for building recovery.....\n"
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C 
source build/envsetup.sh

echo -e "finally lets cook something yummyyyy!!!! prepare to lunch...\n"
if [[ -n $BUILD_LUNCH ]]; then
  lunch ${BUILD_LUNCH}
elif [[ -n $FLAVOR ]]; then
  lunch omni_${DEVICE}-${FLAVOR}
fi

/tmp/keepalive.sh & make -j$(nproc --all) recoveryimage
kill -s SIGTERM $(cat /tmp/keepalive.pid)
echo -e "\nYummy Recovery is Served.....\n"

echo -e "fixing conflict from noob thank uh...\n"
cd out/target/product/${DEVICE}
ls
rm -rf ClassicTheme.zip
ls

echo -e "\n now ready to deploy our build on telegram channel..... \n"
ZIP=$(echo *.zip)
curl -F document=@$ZIP "https://api.telegram.org/bot$token/sendDocument" \
-F chat_id="$chat_id" \
-F "disable_web_page_preview=true" \
-F "parse_mode=html"

echo -e "finally everything done congrats....."
