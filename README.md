##Secret Coffee

Each day my coworkers and I would take a coffee break during the afternoon. Instead of just going when we felt like it, I decided to build Secret Coffee to randomly schedule a time for us to go during a pre-set window and alert our team via Slack. The alerts include a coffee-related quote.

Secret Coffee includes a JSON API with a single endpoint that tells users whether it is Secret Coffee time or not.

Secret Coffee is built using Sinatra, Postgres, and Haml and is deployed on Heroku. A rake task is run once per day to set the coffee break time. Another rake task is run every 10 minutes to check whether it's time for the coffee break and if it is, a notification is pushed to a Slack webhook which alerts the team it's time to go.

[http://secretcoffee.herokuapp.com/](http://secretcoffee.herokuapp.com/)
