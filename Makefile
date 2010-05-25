clean:
	rm -f lmpy.so lmpy.c
lmpy.so: lmpy.pyx lmd.pxd
	python2.6 setup.py build_ext -i
build: lmpy.so
