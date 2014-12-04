var fs = require('fs');
var path = require('path');

var Block = function(type, line) {
  this.type = type;
  this.lines = [line];
};

Block.prototype.append = function(block) {
  this.lines = this.lines.concat(block.lines);
};

Block.prototype.toJSON = function() {
  if (this.type === 'empty') {
    return null;
  }

  return {
    type: this.type,
    lines: this.lines
  };
};

var Blocks = function(blocks) {
  this.blocks = blocks || [];
};

Blocks.prototype.tail = function() {
  return this.blocks.length > 0 && this.blocks[this.blocks.length - 1];
};

Blocks.prototype.append = function(block) {
  var tail = this.tail();
  if (tail && tail.type === block.type) {
    tail.append(block);
  } else {
    this.blocks.push(block);
  }
};

Blocks.prototype.toJSON = function() {
  return this.blocks.map(function(block) {
    return block.toJSON();
  }).filter(function(json) {
    return json !== null;
  });
};

var parse = function(text) {
  var blocks = new Blocks();

  text.split('\n').forEach(function(line) {
    if (/^\s*$/.test(line)) {
      return blocks.append(new Block('empty', ''));
    }

    var result = /^\s*#(.*)$/.exec(line);
    if (result) {
      blocks.append(new Block('text', result[1].trim()));
    } else {
      blocks.append(new Block('code', line));
    }
  });

  return blocks;
};

var load_cheatsheet_in_dir = function(dir) {
  var filenames = fs.readdirSync(dir);
  var cheatsheets = [];
  filenames.forEach(function(filename) {
    var fullpath = path.join(dir, filename);
    var stats = fs.statSync(fullpath);
    if (stats.isFile()) {
      cheatsheets.push({
        blocks: parse(fs.readFileSync(fullpath, 'utf-8')),
        name: filename
      });
    } else if (stats.isDirectory()) {
      cheatsheets = cheatsheets.concat(load_cheatsheet_in_dir(fullpath));
    }
  });
  return cheatsheets;
};

exports.get_cheatsheets = function() {
  return load_cheatsheet_in_dir(
      path.join(__dirname, '../online_cheatsheet'));
};