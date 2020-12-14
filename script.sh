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
            
echo -e "sanity checks.....\n" \

if [[ -z $GIT_EMAIL ]]; then echo -e "You haven't configured GitHub E-Mail Address." && exit 1; fi
if [[ -z $GIT_NAME ]]; then echo -e "You haven't configured GitHub Username." && exit 1; fi
if [[ -z $DEVICE ]]; then echo -e "You haven't configured your device name." && exit 1; fi
if [[ -z $VENDOR ]]; then echo -e "You haven't configured your vendor name." && exit 1; fi
if [[ -z $FLAVOR ]]; then echo -e "Set up your lunch flavor for ex.lunch omni_rmx1925-eng here 'eng' is flavor ." && exit 1; fi
if [[ -z $REC_BRANCH ]]; then echo -e "set recovery branch name." && exit 1; fi

echo -e "initializing variables..." \
     -e GitHubMail="${GitHubMail}" -e GitHubName="${GitHubName}" -e GITHUB_TOKEN="${GITHUB_TOKEN}" \
     -e DEVICE="${DEVICE}" -e VENDOR="${VENDOR}" -e REC_BRANCH="${REC_BRANCH}"
     
echo -e "setting up.......\n" 
mkdir -p ~/bin
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
export PATH=/root/go/bin:$PATH

# go get -u github.com/tcnksm/ghr

echo -e "setting up github....... \n" 
git config --global user.email "${GIT_EMAIL}"
git config --global user.name "${GIT_NAME}"
git config --global color.ui false

[[ ! -d /tmp ]] && mkdir -p /tmp
# Make a keepalive shell so that it can bypass CI Termination on output freeze
cat << EOF > /tmp/keepalive.sh
#!/bin/bash
echo \$$ > /tmp/keepalive.pid # keep this so that it can be killed from other command
while true; do
  echo "." && sleep 300
done
EOF
chmod a+x /tmp/keepalive.sh

echo -e "going to default directory...\n"
cd ~

# sync
echo -e "Initializing ORANGEFOX repo sync..."
repo init -q -u https://gitlab.com/OrangeFox/Manifest.git -b ${REC_BRANCH} --depth 1
/tmp/keepalive.sh && repo sync -c -q --force-sync --no-tags --no-clone-bundle --prune --optimized-fetch -j$(nproc --all) #THREADCOUNT is only 2 in remote docker
kill -s SIGTERM $(cat /tmp/keepalive.pid)

echo -e "cloning device tree and kernel tree on right place....."
git clone https://github.com/abhi9960/twrp_rmx1925 -b ofox device/realme/${DEVICE}
git clone https://github.com/abhi9960/kernel_realme_RMX1911 kernel/realme/${DEVICE}

# See whta's inside
echo -e "\n" && ls -lA .

echo -e "setting up envernment for building recovery....."
export ALLOW_MISSING_DEPENDENCIES=true
export LC_ALL=C 
source build/envsetup.sh

echo -e "finally lets cook something yummy prepare for lunch..."
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
