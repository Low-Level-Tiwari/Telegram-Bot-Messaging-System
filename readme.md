
# Telegram Bot Messaging System

## Overview

The **Telegram Bot Messaging System** connects a Telegram bot with a backend managed by a bash script. The bash script sends requests to the Telegram server and receives HTTP responses, which are then parsed and inserted into a **PostgreSQL** table. This table has triggers that manage routing and processing based on the inserted data. The PostgreSQL database handles all required actions, writes a status code, and the bash script reads this status to determine whether the action succeeded or failed.

### **Use of Psql Database as Web Server**

The system leverages **PostgreSQL** not only for data storage but also as a web server. Using **PL/pgSQL triggers, procedures, and functions**, the database handles routing, processes requests, and responds with status codes. The bash script interacts with the database to monitor actions and error codes.

## Features

- **Telegram Bot Interface**: Interact with Telegram through the bot.
- **Bash Script Logic**: Sends requests to the Telegram server, parses responses, and interacts with PostgreSQL.
- **PostgreSQL Database**: Utilizes **PL/pgSQL triggers, procedures, and functions** to handle web server tasks, manage routing, and process requests.
- **Status Codes**: Bash script checks the status and error codes from PostgreSQL tables to track the success or failure of actions.

## Installation

### Prerequisites

- **PostgreSQL** for database management.
- **Bash** for scripting.
- A **Telegram Bot API Token** to interact with Telegram.

### Setup Instructions

1. Clone the repository:

   ```bash
   git clone https://github.com/Low-Level-Tiwari/Telegram-Bot-Messaging-System.git
   cd Telegram-Bot-Messaging-System
   ```

2. Configure the PostgreSQL database by running the SQL schema files:

   ```bash
   psql -U postgres -d your_database_name -f schema.sql
   psql -U postgres -d your_database_name -f trig.sql
   ```

3. Set up the Telegram bot with your API token and the bash script to handle messaging logic.

### Running the System

After setup, run the bot using the provided bash script:

```bash
./start_fbsd_1
```

This starts the bot and integrates it with the PostgreSQL database.

## License

This project is licensed under the MIT License. See the LICENSE file for more details.

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

## Contact

For any inquiries, please reach out via GitHub Issues.
