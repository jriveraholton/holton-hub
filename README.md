# holton-hub
## Advanced Web Development Course Project (2024-25)

***This project runs on Ruby 3.3.6***

### Setting Up the Project Gems

Run the following command to install gems after moving into your project directory in your terminal.
```
bundle install
```

### Building the Database

To generate the database file from the exisitng migrations run the following command:
```
bundle exec rake db:migrate
```

###Loading the Database with Data

To fill some tables with necessary data, run the following command:
```
bundle exec rake db:seed
```

###Secret Keys File

Don't forget to ask Mr. Rivera about the secret keys file you ***must*** have for google login to work!