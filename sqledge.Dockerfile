# ./docker/sqledge.Dockerfile
FROM mcr.microsoft.com/azure-sql-edge:latest

USER root

# Create required directories and set permissions
RUN mkdir -p /var/lib/apt/lists/partial && \
  chmod 755 /var/lib/apt/lists/partial

# Install prerequisites and SQL tools
RUN apt-get update && \
  apt-get install -y curl gnupg2 unixodbc-dev && \
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
  curl https://packages.microsoft.com/config/debian/11/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
  apt-get update && \
  ACCEPT_EULA=Y apt-get install -y mssql-tools18 msodbcsql18 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

# Add SQL tools to PATH
ENV PATH="/opt/mssql-tools18/bin:${PATH}"

# Switch back to mssql user
USER mssql

CMD [ "/opt/mssql/bin/sqlservr" ]