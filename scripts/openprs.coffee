# Description:
#   Show open pull requests for repositories your team cares about, sorted by oldest first.
#
# Dependencies:
#   "githubot": "0.3.x"
#
# Configuration:
#   OPENPRS_GITHUB_OATH_TOKEN - OAuth token for accessing private repositories
#
# Commands:
#   hubot prs for <team> - view pull requests for watched repositories
#   hubot prs new <team> - start a new <team>
#   hubot prs watch <team> <repo> - watch a repository
#   hubot prs ignore <team> <repo> - ignore a repository
#   hubot prs repos <team> - see what <team> is watching
#
# Author:
#   nwolfe

github = require('githubot')

GITHUB_OATH_TOKEN = process.env.OPENPRS_GITHUB_OATH_TOKEN
unless GITHUB_OATH_TOKEN
  console.warn "Please set the OPENPRS_GITHUB_OATH_TOKEN environment variable."

module.exports = (robot) ->
  cache = {}
  robot.brain.on 'loaded', =>
    if robot.brain.data.prs
      cache = robot.brain.data.prs

  # prs for <team>
  robot.respond /prs for (\S+)/i, (msg) ->
    team = msg.match[1]
    print_open_prs(team, msg, cache)

  # prs new <team>
  robot.respond /prs new (\S+)/i, (msg) ->
    team = msg.match[1]
    start_new_team(team, msg, cache, robot)

  # prs watch <team> <repo>
  robot.respond /prs watch (\S+) (\S+)/i, (msg) ->
    team = msg.match[1]
    repo = msg.match[2]
    watch_repo(team, repo, msg, cache, robot)

  # prs ignore <team> <repo>
  robot.respond /prs ignore (\S+) (\S+)/i, (msg) ->
    team = msg.match[1]
    repo = msg.match[2]
    ignore_repo(team, repo, msg, cache, robot)

  # prs repos <team>
  robot.respond /prs repos (\S+)/i, (msg) ->
    team = msg.match[1]
    print_repos(team, msg, cache)

save = (cache, robot) ->
  robot.brain.data.prs = cache

start_new_team = (team, msg, cache, robot) ->
  if cache[team]
    msg.send "That team already exists."
  else
    cache[team] = []
    save(cache, robot)
    msg.send "Welcome #{team} team!"

watch_repo = (team, repo, msg, cache, robot) ->
  if !cache[team]
    msg.send "I don't know the #{team} team."
  else if cache[team].indexOf(repo) >= 0
    msg.send "They're already watching that repository."
  else
    cache[team].push(repo)
    save(cache, robot)
    msg.send "#{team} team is now watching #{repo}!"

ignore_repo = (team, repo, msg, cache, robot) ->
  if !cache[team]
    msg.send "I don't know the #{team} team."
  else if cache[team].indexOf(repo) < 0
    msg.send "They're not watching that repository."
  else
    index = cache[team].indexOf(repo)
    if cache[team].splice(index, 1)
      save(cache, robot)
      msg.send "#{team} team is all done with #{repo}!"

print_repos = (team, msg, cache) ->
  if !cache[team]
    msg.send "I don't know the #{team} team."
  else if cache[team].length < 1
    msg.send "They're not watching any repositories."
  else
    result = 'Repositories:'
    result += '\n' + repo for repo in cache[team]
    msg.send result

print_open_prs = (team, msg, cache) ->
  if !cache[team]
    msg.send "I don't know the #{team} team."
  else if cache[team].length == 0
    msg.send "They're not watching any repositories."
  else
    copy = []
    copy.push(repo) for repo in cache[team]
    print_open_prs_recur(copy, msg, [])

print_open_prs_recur = (repos, msg, accum) ->
  repo = repos.shift()
  url = "https://api.github.com/repos/#{repo}/pulls?"
  url += "access_token=#{GITHUB_OATH_TOKEN}" if GITHUB_OATH_TOKEN
  github.get url, (pull_requests) ->
    accum = accum.concat(pull_requests)
    if repos.length == 0
      oldest_first = accum.sort (a, b) -> new Date(a['created_at']) - new Date(b['created_at'])
      print_prs(oldest_first, msg)
    else
      print_open_prs_recur(repos, msg, accum)

print_prs = (prs, msg) ->
  result = 'Pull Requests:'
  result += '\n' + pr_info(pr) for pr in prs
  msg.send result

pr_info = (pr) ->
  title = pr['title']
  url = pr['html_url']
  age = age_stamp(pr)
  "#{title} - #{age} - #{url}"

age_stamp = (pr) ->
  ms = new Date() - new Date(pr['created_at'])
  seconds = ms / 1000
  days = Math.floor((seconds % 31536000) / 86400)
  hours = Math.floor(((seconds % 31536000) % 86400) / 3600)
  minutes = Math.floor((((seconds % 31536000) % 86400) % 3600) / 60)
  if days > 0
    "#{days}d #{hours}h"
  else if hours > 0
    "#{hours}h #{minutes}m"
  else if minutes > 0
    "#{minutes}m #{seconds}s"
  else if seconds > 0
    "#{seconds}s"
  else
    "0s"
