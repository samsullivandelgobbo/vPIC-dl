# setup.py
from setuptools import setup

setup(
    name="vpic-pipeline",
    version="0.1.0",
    description="vPIC Database Pipeline Tool",
    author="Sam",
    py_modules=["migrate", "database", "settings"],
    package_dir={"": "src"},
    python_requires=">=3.8",
    install_requires=[
        "pyodbc>=5.0.1",
        "psycopg2-binary==2.9.9",
        "tqdm==4.66.1",
        "pytest==7.4.3",
        "python-dotenv==1.0.0",
        "setuptools>=42.0.0",
    ],
    entry_points={
        "console_scripts": [
            "vpic-pipeline=migrate:main",
        ],
    },
)