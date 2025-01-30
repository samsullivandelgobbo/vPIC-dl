# setup.py
from setuptools import setup, find_packages

setup(
    name="vpic_migration",
    version="0.1.0",
    description="vPIC Database Migration Tool",
    author="Sam",
    packages=find_packages(),
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
            "vpic-migrate=vpic_migration.migrate:main",
        ],
    },
)