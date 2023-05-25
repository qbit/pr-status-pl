build: elm append fix clean

elm: src/Main.elm
	elm make --optimize src/Main.elm


append:
	sed -i '/<!DOCTYPE HTML>/,$$d' pr-status.pl
	cat index.html >> pr-status.pl


fix:
	sed -i 's/<title>Main/<title>pr-status/' pr-status.pl

clean:
	rm -f index.html

