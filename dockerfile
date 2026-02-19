# Use the official Debian image as the base
FROM debian:bookworm-slim

# Set the working directory inside the container
WORKDIR /app

# Optional: Install any necessary packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    jq \
    curl \
    nano \
    && rm -rf /var/lib/apt/lists/*

# Copy the test script into the container
COPY tests.sh .

RUN chmod +x tests.sh

# Command to run when the container starts
CMD ["/bin/bash -c ./tests.sh"]
