from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

ext_modules = [
    Extension("lmpy", ["lmpy.pyx"],
              libraries=["loudmouth-1", "idn"],
              include_dirs=["/usr/local/include/loudmouth-1.0", "/usr/include/glib-2.0", "/usr/lib/glib-2.0/include/"])
    ]

setup(
  name = 'LM library',
  cmdclass = {'build_ext': build_ext},
  ext_modules = ext_modules
)
