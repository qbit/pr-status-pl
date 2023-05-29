build: elm append fmt clean

fmt: pr-status.pl
	perltidy -b pr-status.pl

elm: src/Main.elm
	elm make --optimize src/Main.elm


append:
	sed -i '/<!DOCTYPE HTML>/,$$d' pr-status.pl
	cat index.html >> pr-status.pl


clean:
	rm -f index.html

