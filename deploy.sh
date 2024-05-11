sudo apt update
sudo apt install g++-10
sudo unlink /usr/bin/g++
sudo ln -s /usr/bin/g++-10 /usr/bin/g++
sudo apt install ragel exiftool --no-install-recommends

# install ruby

gem install bundler
cd lib/dtext_rb
bin/install
cd ../..
bundle install

yarn install
bin/rails assets:precompile

/usr/bin/python3.8 -m pip install pillow
