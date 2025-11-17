all: test

test: solution.c solution.o
	gcc -no-pie solution.c solution.o -o solution

solution.o: solution.s
	nasm -felf64 solution.s -o solution.o

clean:
	rm -f *.o solution

