
module.exports = {
  releases: data => Object.values(data.releasesByTag).sort().reverse()
}
