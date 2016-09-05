# Description:
#   A hubot script for manage AWS ECS cluster
#
# Dependencies:
#   "shelljs": ">= 0.5.3"
#
# Configuration
#   HUBOT_ECS_AUTHORIZED_ROLES - Restrict users with a list of authorized roles (need to install hubot-auth)
#   HUBOT_ECS_CLUSTER_PATH - The directory to put your ECS cluster Docker compose file
#
# Commands:
#  hubot ecs-cli list-cluster - Lists all of the ECS clusters.
#  hubot ecs-cli <cluster name> list-project - Lists all of the ECS projects in your cluster.
#  hubot ecs-cli <cluster name> ps - Lists all of the running containers in default ECS cluster.
#  hubot ecs-cli <cluster name> <project name> compose service ps - Lists all the containers in your cluster that belong to the service created with the compose project.
#  hubot ecs-cli <cluster name> <project name> compose service up - Creates an ECS service from your compose file (if it does not already exist) and runs one instance of that task on your cluster (a combination of create and start). This command updates the desired count of the service to 1.
#  hubot ecs-cli <cluster name> <project name> list-image - Lists all the images in your cluster that belong to the service created with the compose project.
#  hubot ecs-cli <cluster name> <project name> update-image <new image> - Updates your compose file with the new image.
#
# Author:
#   Kevin Li

fs = require("fs")
path = require 'path'

defaultECSClusterPath = path.join __dirname, '..', 'ecs_cluster'

if process.env.HUBOT_ECS_AUTHORIZED_ROLES
  authorizedRoles = process.env.HUBOT_ECS_AUTHORIZED_ROLES
else
  authorizedRoles = 'admin,ecs_admin'

if process.env.HUBOT_ECS_CLUSTER_PATH
  hubotECSClusterPath = process.env.HUBOT_ECS_CLUSTER_PATH
else
  hubotECSClusterPath = defaultECSClusterPath

if not fs.existsSync(hubotECSClusterPath)
  console.log "#{hubotECSClusterPath} not found in hubot working dir, using to default dir: #{hubotECSClusterPath}"
  hubotECSClusterPath = defaultECSClusterPath

imagePattern = /// ^  # begin of line
  ([-.\w]+)           # domain
  :?([\d]+)?          # port
  /([-\w]+)           # repo
  /?([-\w]+)?         # img
  :?([-.\w]+)?        # tag
  $ ///               # end of line

rootRepoPattern = /// ^  # begin of line
  ([-\w]+)             # img
  :?([-.\w]+)?         # tag
  $ ///                # end of line

hasAnAuthorizedRole = (robot, user, cluster) ->
  for r in robot.auth.userRoles user
    return true if r in authorizedRoles.split(',') or r is "#{cluster}_admin"
  return false

isAuthorized = (robot, user, cluster, res) ->
  hasHubotAuth = robot.auth? and robot.auth.hasRole?
  mustRestrictWithRoles = hasHubotAuth and authorizedRoles?
  (not mustRestrictWithRoles) or hasAnAuthorizedRole robot, user, cluster

displayResult = (robot, res, cluster, project, command, text) ->
  if robot.adapterName != "slack"
    res.reply "Cluster: #{cluster}, Project: #{project}\nCommand: #{command}\n#{text}"
  else
    robot.emit 'slack-attachment',
      channel: "#{res.message.user.room}"
      content:
        color: "#55acee"
        fallback: "#{text}"
        title: "#{cluster}-#{project}: #{command}"
        text: "#{text}"

getClusters = (srcPath) ->
  clusters = (file for file in fs.readdirSync(srcPath) when fs.statSync(path.join(srcPath, file)).isDirectory())

getProjects = (srcPath) ->
  projects = (file.substring(0, file.length - 4) for file in fs.readdirSync(srcPath) when fs.statSync(path.join(srcPath, file)).isFile() and file.endsWith('.yml'))

runECSCompose = (robot, cluster, project, command, res) ->
  shell = require('shelljs')
  projectPath = path.join hubotECSClusterPath, cluster, project
  composeFile = "#{projectPath}.yml"
  ecsCli = "ecs-cli compose --file #{composeFile} --project-name #{project} #{command}"
  console.log ecsCli
  shell.exec ecsCli, {async:true}, (code, stdout, stderr) ->
    displayResult robot, res, cluster, project, "compose #{command}", stdout

listImage = (robot, cluster, project, res) ->
  shell = require('shelljs')
  projectPath = path.join hubotECSClusterPath, cluster, project
  composeFile = "#{projectPath}.yml"
  result = []
  for line in fs.readFileSync(composeFile).toString().split '\n'
    if line.match /^[^\s]+:\s*$/
      result.push line
    if line.match /^[\s]+image:/
      result.push line
  displayResult robot, res, cluster, project, "list-image", result.join '\n'

parseImage = (image) ->
  if image.match(imagePattern)
    imageMatch = image.match(imagePattern)
    domain = imageMatch[1]
    port = imageMatch[2]
    repo = imageMatch[3]
    img = imageMatch[4]
    tag = imageMatch[5]
    useImage = ''
    if domain
      useImage = domain
    if port
      useImage = "#{useImage}:#{port}"
    if repo
      useImage = "#{useImage}/#{repo}"
    if img
      useImage = "#{useImage}/#{img}"
    imageWithoutTag = useImage
    if tag
      useImage = "#{useImage}:#{tag}"
    return [useImage, imageWithoutTag]
  else if image.match(rootRepoPattern)
    imageMatch = image.match(rootRepoPattern)
    img = imageMatch[1]
    tag = imageMatch[2]
    if img
      useImage = "#{img}"
    imageWithoutTag = useImage
    if tag
      useImage = "#{useImage}:#{tag}"
    return [useImage, imageWithoutTag]
  else
    return [undefined, undefined]

updateImage = (robot, cluster, project, useImage, imageWithoutTag, res) ->
  projectPath = path.join hubotECSClusterPath, cluster, project
  composeFile = "#{projectPath}.yml"
  imageWithoutTagPattern = new RegExp("(^[\\s]+image:[\\s]+)(#{imageWithoutTag}.*)$")
  newContent = []
  oldContent = fs.readFileSync(composeFile).toString()
  for line in oldContent.split '\n'
    imageWithoutTagMatch = line.match imageWithoutTagPattern
    if imageWithoutTagMatch
      newLine = "#{imageWithoutTagMatch[1]}#{useImage}"
      newContent.push newLine
      text = "old image: #{imageWithoutTagMatch[2]}\nnew image: #{useImage}"
    else
      newContent.push line
  fs.writeFileSync composeFile, newContent.join '\n'
  console.log "ecs-cli update-image: User: #{res.message.user.name}, Cluster: #{cluster}, Project: #{project}, Result: #{text}"
  displayResult robot, res, cluster, project, "update-image", text

module.exports = (robot) ->
  #  hubot ecs-cli list-cluster
  robot.respond /ecs-cli\s+list-cluster/i, (res) ->
    clusters = getClusters hubotECSClusterPath
    console.log "ecs-cli list-cluster: User: #{res.message.user.name}"
    res.reply "Clusters:\n#{clusters.join('\n')}"

  #  hubot ecs-cli <cluster name> list-project
  robot.respond /ecs-cli\s+([^\s]+)\s+list-project/i, (res) ->
    cluster = res.match[1].trim() || 'default'
    clusterPath = path.join hubotECSClusterPath, cluster
    authorized = isAuthorized robot, res.envelope.user, cluster, res
    console.log "ecs-cli list-project: User: #{res.message.user.name}, Cluster: #{cluster}, Cluster path: #{clusterPath}"

    if authorized
      if fs.existsSync clusterPath
        projects = getProjects clusterPath
        res.reply "Projects in #{cluster}:\n#{projects.join('\n')}"
      else
        res.reply "Cluster: #{cluster} not exists"
    else
      res.reply "I can't do that, you need at least one of these roles: #{authorizedRoles},#{cluster}_admin"

  #  hubot ecs-cli <cluster name> <project name> compose <sub command>
  robot.respond /ecs-cli\s+([^\s]+)\s+([^\s]+)\s+compose\s+(.+)/i, (res) ->
    cluster = res.match[1].trim() || 'default'
    project = res.match[2].trim() || 'default'
    command = res.match[3].trim() || '--help'
    authorized = isAuthorized robot, res.envelope.user, cluster, res
    console.log "ecs-cli compose: User: #{res.message.user.name}, Cluster: #{cluster}, Project: #{project}, Command: #{command}"

    if authorized
      runECSCompose robot, cluster, project, command, res
    else
      res.reply "I can't do that, you need at least one of these roles: #{authorizedRoles},#{cluster}_admin"

  #  hubot ecs-cli <cluster name> <project name> list-image
  robot.respond /ecs-cli\s+([^\s]+)\s+([^\s]+)\s+list-image/i, (res) ->
    cluster = res.match[1].trim() || 'default'
    project = res.match[2].trim() || 'default'
    authorized = isAuthorized robot, res.envelope.user, cluster, res
    console.log "ecs-cli list-image User: #{res.message.user.name}, Cluster: #{cluster}, Project: #{project}, Command: list-image"

    if authorized
      listImage robot, cluster, project, res
    else
      res.reply "I can't do that, you need at least one of these roles: #{authorizedRoles},#{cluster}_admin"

  #  hubot ecs-cli <cluster name> <project name> update-image <new image>
  robot.respond /ecs-cli\s+([^\s]+)\s+([^\s]+)\s+update-image\s+([^\s]+)/i, (res) ->
    cluster = res.match[1].trim() || 'default'
    project = res.match[2].trim() || 'default'
    image = res.match[3].trim() || '--help'
    if image.startsWith 'http://'
      image = image.slice 7
    if image.startsWith 'https://'
      image = image.slice 8
    authorized = isAuthorized robot, res.envelope.user, cluster, res
    console.log "ecs-cli update-image User: #{res.message.user.name}, Cluster: #{cluster}, Project: #{project}, Command: update-image, image: #{image}"

    if authorized
      [useImage, imageWithoutTag] = parseImage image
      if useImage
        updateImage robot, cluster, project, useImage, imageWithoutTag, res
      else
        text = "Unable to parse image name: #{image}, check the format and try again."
        displayResult robot, res, cluster, project, "update-image", text
    else
      res.reply "I can't do that, you need at least one of these roles: #{authorizedRoles},#{cluster}_admin"
