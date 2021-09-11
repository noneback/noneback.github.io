hugo
msg=$(date +20%y-%m-%d)

git add -A
git commit -m "update : ${msg}"
git push -u origin main

cd public
git add -A
git commit -m "update : ${msg}"
git push -u origin master
cd ..


