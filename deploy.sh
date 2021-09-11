hugo
cd public
git add -A
msg=$(date +20%y-%m-%d)
git commit -m "update : ${msg}"
git push -u origin master
cd ..


