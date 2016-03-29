* This application reads GitHub archive dataset (`CSV` format, obtained by Google BigQuery), and query needed data from GitHub API.
* Each entry of event will save to MongoDB `githubData` collection, `datamining` database
* Put all `CSV` file in `data/` folder
* Config the `githubapi.json` (api key)
```json
{
  "client_id": "your_client_id",
  "client_secret": "your_client_secret"
}
```