all: test

test: solution.c solution3.o
	gcc -no-pie solution.c solution3.o -o solution

solution3.o: solution3.s
	nasm -felf64 solution3.s -o solution3.o

clean:
	rm -f *.o solution

