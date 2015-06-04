(function() {
  var App, Comment, Game, Note, Tag, User, app,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Game = (function() {
    function Game(json) {
      this.game_id = parseInt(json.game_id);
      this.name = json.name;
      this.latitude = parseFloat(json.map_latitude);
      this.longitude = parseFloat(json.map_longitude);
      this.zoom = parseInt(json.map_zoom_level);
    }

    return Game;

  })();

  User = (function() {
    function User(json) {
      this.user_id = parseInt(json.user_id);
      this.display_name = json.display_name || json.user_name;
    }

    return User;

  })();

  Tag = (function() {
    function Tag(json) {
      var ref, ref1;
      this.icon_url = (ref = json.media) != null ? (ref1 = ref.data) != null ? ref1.url : void 0 : void 0;
      this.tag = json.tag;
      this.tag_id = parseInt(json.tag_id);
    }

    return Tag;

  })();

  Comment = (function() {
    function Comment(json) {
      this.description = json.description;
      this.comment_id = parseInt(json.note_comment_id);
      this.user = new User(json.user);
      this.created = new Date(json.created.replace(' ', 'T') + 'Z');
    }

    return Comment;

  })();

  Note = (function() {
    function Note(json) {
      var o;
      this.note_id = parseInt(json.note_id);
      this.user = new User(json.user);
      this.description = json.description;
      this.photo_url = parseInt(json.media.data.media_id) === 0 ? null : json.media.data.url;
      this.thumb_url = parseInt(json.media.data.media_id) === 0 ? null : json.media.data.thumb_url;
      this.latitude = parseFloat(json.latitude);
      this.longitude = parseFloat(json.longitude);
      this.tag_id = parseInt(json.tag_id);
      this.created = new Date(json.created.replace(' ', 'T') + 'Z');
      this.player_liked = parseInt(json.player_liked) !== 0;
      this.note_likes = parseInt(json.note_likes);
      this.comments = (function() {
        var j, len, ref, results;
        ref = json.comments.data;
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          o = ref[j];
          results.push(new Comment(o));
        }
        return results;
      })();
      this.published = json.published;
    }

    return Note;

  })();

  App = (function() {
    function App() {
      $(document).ready((function(_this) {
        return function() {
          _this.aris = new Aris;
          return _this.login(void 0, void 0, function() {
            _this.siftr_url = null;
            _this.siftr_id = 6234;
            return _this.getGameInfo(function() {
              return _this.getGameOwners(function() {
                _this.createMap();
                return _this.getGameTags(function() {
                  _this.makeTagLists();
                  return _this.performSearch(function() {
                    return _this.installListeners();
                  });
                });
              });
            });
          });
        };
      })(this));
    }

    App.prototype.getGameInfo = function(cb) {
      if (this.siftr_url != null) {
        return this.aris.call('games.searchSiftrs', {
          siftr_url: this.siftr_url
        }, (function(_this) {
          return function(arg) {
            var games, returnCode;
            games = arg.data, returnCode = arg.returnCode;
            if (returnCode === 0 && games.length === 1) {
              _this.game = new Game(games[0]);
              $('#the-siftr-title').text(_this.game.name);
              return cb();
            } else {
              return _this.error("Failed to retrieve the Siftr game info");
            }
          };
        })(this));
      } else if (this.siftr_id != null) {
        return this.aris.call('games.getGame', {
          game_id: this.siftr_id
        }, (function(_this) {
          return function(arg) {
            var game, returnCode;
            game = arg.data, returnCode = arg.returnCode;
            _this.game = new Game(game);
            $('#the-siftr-title').text(_this.game.name);
            return cb();
          };
        })(this));
      } else {
        return this.error("No Siftr specified");
      }
    };

    App.prototype.getGameOwners = function(cb) {
      return this.aris.call('users.getUsersForGame', {
        game_id: this.game.game_id
      }, (function(_this) {
        return function(arg) {
          var commaList, names, o, owners, returnCode, user;
          owners = arg.data, returnCode = arg.returnCode;
          if (returnCode === 0) {
            _this.game.owners = (function() {
              var j, len, results;
              results = [];
              for (j = 0, len = owners.length; j < len; j++) {
                o = owners[j];
                results.push(new User(o));
              }
              return results;
            })();
            _this.checkIfOwner();
            if (_this.game.owners.length > 0) {
              names = (function() {
                var j, len, ref, results;
                ref = this.game.owners;
                results = [];
                for (j = 0, len = ref.length; j < len; j++) {
                  user = ref[j];
                  results.push(user.display_name);
                }
                return results;
              }).call(_this);
              commaList = function(list) {
                switch (list.length) {
                  case 0:
                    return "";
                  case 1:
                    return list[0];
                  default:
                    return (list.slice(0, -1).join(', ')) + " and " + list[list.length - 1];
                }
              };
              $('#the-siftr-subtitle').text("Started by " + (commaList(names)));
            }
          } else {
            _this.game.owners = [];
            _this.warn("Failed to retrieve the list of Siftr owners");
          }
          return cb();
        };
      })(this));
    };

    App.prototype.centerMapOffset = function(latlng, offsetx, offsety) {
      var p1, p2, z;
      if (latlng == null) {
        latlng = this.map.getCenter();
      }
      if (offsetx == null) {
        offsetx = 0;
      }
      if (offsety == null) {
        offsety = 0;
      }
      p1 = this.map.getProjection().fromLatLngToPoint(latlng);
      z = this.map.getZoom();
      p2 = new google.maps.Point(offsetx / (Math.pow(2, z)), offsety / (Math.pow(2, z)));
      return this.map.setCenter((function(_this) {
        return function() {
          return _this.map.getProjection().fromPointToLatLng((function() {
            return new google.maps.Point(p1.x - p2.x, p1.y - p2.y);
          })());
        };
      })(this)());
    };

    App.prototype.setMapCenter = function(latlng) {
      var listener, offsetx, w;
      w = $('body').width();
      if (w < 907) {
        return this.map.setCenter(latlng);
      } else {
        offsetx = (w - 450 - 30) / 2 - w / 2;
        if (this.map.getProjection() != null) {
          return this.centerMapOffset(latlng, offsetx, 0);
        } else {
          return listener = google.maps.event.addListener(this.map, 'projection_changed', (function(_this) {
            return function() {
              if (_this.map.getProjection() != null) {
                _this.centerMapOffset(latlng, offsetx, 0);
                return google.maps.event.removeListener(listener);
              }
            };
          })(this));
        }
      }
    };

    App.prototype.createMap = function() {
      this.mapCenter = new google.maps.LatLng(this.game.latitude, this.game.longitude);
      this.map = new google.maps.Map($('#the-map')[0], {
        zoom: this.game.zoom,
        center: this.mapCenter,
        mapTypeId: google.maps.MapTypeId.ROADMAP,
        panControl: false,
        zoomControl: false,
        mapTypeControl: false,
        scaleControl: false,
        streetViewControl: false,
        overviewMapControl: false,
        styles: window.mapStyle.concat({
          featureType: 'poi',
          elementType: 'labels',
          stylers: [
            {
              visibility: 'off'
            }
          ]
        })
      });
      this.setMapCenter(this.mapCenter);
      return this.dragMarker = new google.maps.Marker({
        position: this.mapCenter,
        map: null,
        draggable: true,
        zIndexProcess: function() {
          return 9999;
        }
      });
    };

    App.prototype.getGameTags = function(cb) {
      return this.aris.call('tags.getTagsForGame', {
        game_id: this.game.game_id
      }, (function(_this) {
        return function(arg) {
          var o, returnCode, tags;
          tags = arg.data, returnCode = arg.returnCode;
          if (returnCode === 0) {
            _this.game.tags = (function() {
              var j, len, results;
              results = [];
              for (j = 0, len = tags.length; j < len; j++) {
                o = tags[j];
                results.push(new Tag(o));
              }
              return results;
            })();
            return cb();
          } else {
            return _this.error("Failed to retrieve the list of tags");
          }
        };
      })(this));
    };

    App.prototype.makeTagLists = function() {
      appendTo($('#the-search-tags'), 'form', {}, (function(_this) {
        return function(form) {
          var j, len, ref, results, t;
          ref = _this.game.tags;
          results = [];
          for (j = 0, len = ref.length; j < len; j++) {
            t = ref[j];
            results.push(appendTo(form, 'p', {}, function(p) {
              return appendTo(p, 'label', {}, function(label) {
                appendTo(label, 'input', {
                  type: 'checkbox',
                  checked: false,
                  value: t.tag_id
                });
                return label.append(document.createTextNode(t.tag));
              });
            }));
          }
          return results;
        };
      })(this));
      return appendTo($('#the-tag-assigner'), 'form', {}, (function(_this) {
        return function(form) {
          var i, j, len, ref, results, t;
          ref = _this.game.tags;
          results = [];
          for (i = j = 0, len = ref.length; j < len; i = ++j) {
            t = ref[i];
            results.push(appendTo(form, 'p', {}, function(p) {
              return appendTo(p, 'label', {}, function(label) {
                appendTo(label, 'input', {
                  type: 'radio',
                  checked: i === 0,
                  name: 'upload-tag',
                  value: t.tag_id
                });
                return label.append(document.createTextNode(t.tag));
              });
            }));
          }
          return results;
        };
      })(this));
    };

    App.prototype.performSearch = function(cb) {
      var box, tag_ids, thisSearch;
      thisSearch = this.lastSearch = Date.now();
      tag_ids = (function() {
        var j, len, ref, results;
        ref = $('#the-search-tags input[type="checkbox"]');
        results = [];
        for (j = 0, len = ref.length; j < len; j++) {
          box = ref[j];
          if (!box.checked) {
            continue;
          }
          results.push(parseInt(box.value));
        }
        return results;
      })();
      return this.aris.call('notes.searchNotes', {
        game_id: this.game.game_id,
        tag_ids: tag_ids,
        order_by: 'recent'
      }, (function(_this) {
        return function(arg) {
          var n, notes, o, returnCode;
          notes = arg.data, returnCode = arg.returnCode;
          if (returnCode === 0) {
            if (thisSearch === _this.lastSearch) {
              _this.game.notes = (function() {
                var j, len, results;
                results = [];
                for (j = 0, len = notes.length; j < len; j++) {
                  o = notes[j];
                  results.push(new Note(o));
                }
                return results;
              })();
              _this.game.notes = (function() {
                var j, len, ref, results;
                ref = this.game.notes;
                results = [];
                for (j = 0, len = ref.length; j < len; j++) {
                  n = ref[j];
                  if (n.photo_url != null) {
                    results.push(n);
                  }
                }
                return results;
              }).call(_this);
              _this.updateGrid();
              _this.updateMap();
            }
            return cb();
          } else {
            return _this.error("Failed to search for notes");
          }
        };
      })(this));
    };

    App.prototype.updateGrid = function() {
      var grid, i, j, len, note, ref, results, tr;
      $('#the-note-grid').html('');
      grid = $('#the-note-grid');
      tr = null;
      ref = this.game.notes;
      results = [];
      for (i = j = 0, len = ref.length; j < len; i = ++j) {
        note = ref[i];
        results.push((function(_this) {
          return function(note) {
            var td;
            if (i % 3 === 0) {
              tr = appendTo(grid, '.a-grid-row');
            }
            td = appendTo(tr, '.a-grid-photo', {
              style: note.thumb_url != null ? "background-image: url(\"" + note.thumb_url + "\");" : "background-color: black;",
              alt: note.description
            });
            return td.click(function() {
              return _this.showNote(note);
            });
          };
        })(this)(note));
      }
      return results;
    };

    App.prototype.updateMap = function() {
      var j, len, marker, note, ref;
      if (this.markers != null) {
        ref = this.markers;
        for (j = 0, len = ref.length; j < len; j++) {
          marker = ref[j];
          marker.setMap(null);
        }
      }
      return this.markers = (function() {
        var k, len1, ref1, results;
        ref1 = this.game.notes;
        results = [];
        for (k = 0, len1 = ref1.length; k < len1; k++) {
          note = ref1[k];
          results.push((function(_this) {
            return function(note) {
              marker = new google.maps.Marker({
                position: new google.maps.LatLng(note.latitude, note.longitude),
                map: _this.map
              });
              google.maps.event.addListener(marker, 'click', function() {
                return _this.showNote(note);
              });
              note.marker = marker;
              return marker;
            };
          })(this)(note));
        }
        return results;
      }).call(this);
    };

    App.prototype.showNote = function(note) {
      var canDelete, canEdit, canFlag, comment, heart, j, len, ref, ref1, ref2, results;
      if (window.location.hash !== '#' + note.note_id) {
        history.pushState('', '', '#' + note.note_id);
      }
      this.currentNote = note;
      this.scrollBackTo = $('#the-modal-content').scrollTop();
      this.setMode('note');
      $('#the-modal-content').scrollTop(0);
      $('#the-photo').css('background-image', note.photo_url != null ? "url(\"" + note.photo_url + "\")" : '');
      $('#the-photo-link').prop('href', note.photo_url);
      $('#the-photo-caption').text(note.description);
      $('#the-photo-credit').html("Created by <b>" + (escapeHTML(note.user.display_name)) + "</b> at " + (escapeHTML(note.created.toLocaleString())));
      heart = $('#the-like-button i');
      if (note.player_liked) {
        heart.addClass('fa-heart');
        heart.removeClass('fa-heart-o');
      } else {
        heart.addClass('fa-heart-o');
        heart.removeClass('fa-heart');
      }
      canEdit = ((ref = this.aris.auth) != null ? ref.user_id : void 0) === note.user.user_id;
      canDelete = canEdit || this.userIsOwner;
      $('#the-edit-button').toggle(canEdit || canDelete);
      $('#the-start-edit-button').toggle(canEdit);
      $('#the-delete-button').toggle(canDelete);
      canFlag = note.published === 'AUTO' && ((ref1 = this.aris.auth) != null ? ref1.user_id : void 0) !== note.user.user_id;
      $('#the-flag-button').toggle(canFlag);
      $('#the-comments').html('');
      if (note.comments.length > 0) {
        appendTo($('#the-comments'), 'h3', {
          text: 'Comments'
        });
        ref2 = note.comments;
        results = [];
        for (j = 0, len = ref2.length; j < len; j++) {
          comment = ref2[j];
          if (comment.description.match(/\S/)) {
            results.push(appendTo($('#the-comments'), 'div', {}, (function(_this) {
              return function(div) {
                appendTo(div, 'h4', {}, function(h4) {
                  var pencil, ref3;
                  appendTo(h4, 'span', {
                    text: comment.user.display_name + " (" + (comment.created.toLocaleString()) + ")"
                  });
                  if (_this.userIsOwner || ((ref3 = _this.aris.auth) != null ? ref3.user_id : void 0) === comment.user.user_id) {
                    pencil = appendTo(h4, 'i.fa.fa-pencil', {
                      style: 'cursor: pointer;'
                    });
                    return pencil.click(function() {
                      return console.log('TODO: edit/delete comments');
                    });
                  }
                });
                return appendTo(div, 'p', {
                  text: comment.description
                });
              };
            })(this)));
          } else {
            results.push(void 0);
          }
        }
        return results;
      }
    };

    App.prototype.setMode = function(mode) {
      var body, j, k, len, len1, note, oldMode, ref, ref1, ref2, results;
      if (mode !== 'note' && ((ref = window.location.hash) !== '#' && ref !== '')) {
        history.pushState('', '', '#');
      }
      body = $('body');
      oldMode = this.mode;
      this.mode = mode;
      body.removeClass('is-open-menu');
      body.removeClass('is-open-share');
      body.removeClass('is-open-edit');
      this.dragMarker.setMap(null);
      switch (mode) {
        case 'grid':
          this.topMode = 'grid';
          body.removeClass('is-mode-note');
          body.removeClass('is-mode-add');
          body.removeClass('is-mode-map');
          if (this.scrollBackTo != null) {
            $('#the-modal-content').scrollTop(this.scrollBackTo);
            delete this.scrollBackTo;
          }
          break;
        case 'map':
          this.topMode = 'map';
          body.removeClass('is-mode-note');
          body.removeClass('is-mode-add');
          body.addClass('is-mode-map');
          break;
        case 'note':
          body.addClass('is-mode-note');
          body.removeClass('is-mode-add');
          body.removeClass('is-mode-map');
          break;
        case 'add':
          body.removeClass('is-mode-note');
          body.addClass('is-mode-add');
          body.removeClass('is-mode-map');
          this.dragMarker.setMap(this.map);
          this.dragMarker.setPosition(this.mapCenter);
          this.dragMarker.setAnimation(google.maps.Animation.DROP);
          this.setMapCenter(this.mapCenter);
          this.map.setZoom(this.game.zoom);
          $('#the-caption-box').val('');
          $('#the-tag-assigner input[name=upload-tag]:first').click();
          if (oldMode !== 'add') {
            ref1 = this.game.notes;
            for (j = 0, len = ref1.length; j < len; j++) {
              note = ref1[j];
              note.marker.setOpacity(0.3);
            }
          }
      }
      if (oldMode === 'add' && mode !== 'add') {
        ref2 = this.game.notes;
        results = [];
        for (k = 0, len1 = ref2.length; k < len1; k++) {
          note = ref2[k];
          results.push(note.marker.setOpacity(1));
        }
        return results;
      }
    };

    App.prototype.submitNote = function() {
      var desc;
      if (!((this.ext != null) && (this.base64 != null))) {
        this.error('Please select a photo to upload.');
        return;
      }
      desc = $('#the-caption-box').val();
      if (desc.length === 0) {
        this.error('Please enter a caption for the image.');
        return;
      }
      return this.aris.call('notes.createNote', {
        game_id: this.game.game_id,
        media: {
          file_name: "upload." + this.ext,
          data: this.base64,
          resize: 640
        },
        description: desc,
        trigger: {
          latitude: this.dragMarker.getPosition().lat(),
          longitude: this.dragMarker.getPosition().lng()
        },
        tag_id: parseInt($('#the-tag-assigner input[name=upload-tag]:checked').val())
      }, (function(_this) {
        return function(arg) {
          var returnCode, simpleNote;
          simpleNote = arg.data, returnCode = arg.returnCode;
          if (returnCode !== 0) {
            _this.error('There was an error uploading your photo.');
            return;
          }
          return _this.aris.call('notes.searchNotes', {
            game_id: _this.game.game_id,
            note_id: parseInt(simpleNote.note_id),
            note_count: 1
          }, function(arg1) {
            var note, notes, returnCode;
            notes = arg1.data, returnCode = arg1.returnCode;
            if (returnCode !== 0) {
              _this.error('There was an error retrieving your new photo.');
              return;
            }
            note = new Note(notes[0]);
            _this.game.notes.unshift(note);
            _this.updateGrid();
            _this.updateMap();
            return _this.showNote(note);
          });
        };
      })(this));
    };

    App.prototype.needsAuth = function(act) {
      if (this.aris.auth != null) {
        return act();
      } else {
        return $('body').addClass('is-open-menu');
      }
    };

    App.prototype.goToHash = function() {
      var j, len, md, note, note_id, ref;
      if (md = window.location.hash.match(/^#(\d+)$/)) {
        note_id = parseInt(md[1]);
        ref = this.game.notes;
        for (j = 0, len = ref.length; j < len; j++) {
          note = ref[j];
          if (note.note_id === note_id) {
            this.showNote(note);
            return;
          }
        }
      }
      return this.setMode(this.topMode);
    };

    App.prototype.installListeners = function() {
      var body;
      body = $('body');
      this.topMode = 'grid';
      this.goToHash();
      $(window).on('hashchange', (function(_this) {
        return function() {
          return _this.goToHash();
        };
      })(this));
      $('#the-user-logo, #the-menu-button').click((function(_this) {
        return function() {
          return body.toggleClass('is-open-menu');
        };
      })(this));
      $('#the-grid-button').click((function(_this) {
        return function() {
          return _this.setMode('grid');
        };
      })(this));
      $('#the-map-button').click((function(_this) {
        return function() {
          return _this.setMode('map');
        };
      })(this));
      $('#the-add-button').click((function(_this) {
        return function() {
          if (_this.mode === 'add') {
            return _this.setMode(_this.topMode);
          } else {
            return _this.needsAuth(function() {
              _this.setMode('add');
              return _this.readyFile(null);
            });
          }
        };
      })(this));
      $('#the-icon-bar-x, #the-add-cancel-button').click((function(_this) {
        return function() {
          return _this.setMode(_this.topMode);
        };
      })(this));
      $('#the-logout-button').click((function(_this) {
        return function() {
          _this.logout();
          body.removeClass('is-open-menu');
          _this.setMode(_this.topMode);
          return _this.performSearch(function() {});
        };
      })(this));
      $('#the-tag-button').click((function(_this) {
        return function() {
          if (_this.mode === 'map') {
            body.addClass('is-open-tags');
          } else {
            body.toggleClass('is-open-tags');
          }
          _this.setMode('grid');
          return $('#the-modal-content').scrollTop(0);
        };
      })(this));
      $('#the-search-tags input[type="checkbox"]').change((function(_this) {
        return function() {
          return _this.performSearch(function() {});
        };
      })(this));
      $('#the-add-submit-button').click((function(_this) {
        return function() {
          return _this.submitNote();
        };
      })(this));
      $('#the-share-button').click((function(_this) {
        return function() {
          body.toggleClass('is-open-share');
          return body.removeClass('is-open-edit');
        };
      })(this));
      $('#the-edit-button').click((function(_this) {
        return function() {
          body.toggleClass('is-open-edit');
          return body.removeClass('is-open-share');
        };
      })(this));
      $('#the-like-button').click((function(_this) {
        return function() {
          return _this.needsAuth(function() {
            var heart;
            heart = $('#the-like-button i');
            if (_this.currentNote.player_liked) {
              return _this.aris.call('notes.unlikeNote', {
                note_id: _this.currentNote.note_id
              }, function(arg) {
                var returnCode;
                returnCode = arg.returnCode;
                if (returnCode === 0) {
                  _this.currentNote.player_liked = false;
                  heart.addClass('fa-heart-o');
                  return heart.removeClass('fa-heart');
                } else {
                  return _this.error("There was a problem recording your unlike.");
                }
              });
            } else {
              return _this.aris.call('notes.likeNote', {
                note_id: _this.currentNote.note_id
              }, function(arg) {
                var returnCode;
                returnCode = arg.returnCode;
                if (returnCode === 0) {
                  _this.currentNote.player_liked = true;
                  heart.addClass('fa-heart');
                  return heart.removeClass('fa-heart-o');
                } else {
                  return _this.error("There was a problem recording your like.");
                }
              });
            }
          });
        };
      })(this));
      $('#the-flag-button').click((function(_this) {
        return function() {
          if (confirm('Are you sure you want to flag this note for inappropriate content?')) {
            return _this.aris.call('notes.flagNote', {
              note_id: _this.currentNote.note_id
            }, function(arg) {
              var returnCode;
              returnCode = arg.returnCode;
              if (returnCode === 0) {
                return _this.performSearch(function() {
                  return _this.setMode(_this.topMode);
                });
              } else {
                return _this.error("There was a problem recording your flag.");
              }
            });
          }
        };
      })(this));
      $('#the-delete-button').click((function(_this) {
        return function() {
          if (confirm('Are you sure you want to delete this note?')) {
            return _this.aris.call('notes.deleteNote', {
              note_id: _this.currentNote.note_id
            }, function(arg) {
              var returnCode;
              returnCode = arg.returnCode;
              if (returnCode === 0) {
                return _this.performSearch(function() {
                  return _this.setMode(_this.topMode);
                });
              } else {
                return _this.error("There was an error deleting that note.");
              }
            });
          }
        };
      })(this));
      $('#the-login-button').click((function(_this) {
        return function() {
          return _this.login($('#the-username-input').val(), $('#the-password-input').val(), function() {
            if (_this.aris.auth != null) {
              body.removeClass('is-open-menu');
              return _this.performSearch(function() {
                var j, len, note, oldNoteID, ref;
                if (body.hasClass('is-mode-note')) {
                  oldNoteID = _this.currentNote.note_id;
                  _this.currentNote = null;
                  ref = _this.game.notes;
                  for (j = 0, len = ref.length; j < len; j++) {
                    note = ref[j];
                    if (note.note_id === oldNoteID) {
                      _this.currentNote = note;
                      break;
                    }
                  }
                  if (_this.currentNote != null) {
                    return _this.showNote(_this.currentNote);
                  } else {
                    return _this.setMode(_this.topMode);
                  }
                }
              });
            }
          });
        };
      })(this));
      $('#the-username-input, #the-password-input').keypress((function(_this) {
        return function(e) {
          if (e.which === 13) {
            $('#the-login-button').click();
            return false;
          }
        };
      })(this));
      $('#the-photo-upload-box').on('dragover dragenter', (function(_this) {
        return function(e) {
          return false;
        };
      })(this));
      $('#the-photo-upload-box').on('drop', (function(_this) {
        return function(e) {
          var xfer;
          if (xfer = e.originalEvent.dataTransfer) {
            if (xfer.files.length) {
              _this.readyFile(xfer.files[0]);
              return false;
            }
          }
        };
      })(this));
      $('#the-photo-upload-box').click((function(_this) {
        return function() {
          return $('#the-hidden-file-input').click();
        };
      })(this));
      return $('#the-hidden-file-input').on('change', (function(_this) {
        return function() {
          return _this.readyFile($('#the-hidden-file-input')[0].files[0]);
        };
      })(this));
    };

    App.prototype.readyFile = function(file) {
      var reader;
      delete this.ext;
      delete this.base64;
      $('#the-photo-upload-box').css('background-image', '');
      if (file != null) {
        reader = new FileReader();
        reader.onload = (function(_this) {
          return function(e) {
            var dataURL, ext, mime, prefix, results, typeMap;
            dataURL = e.target.result;
            typeMap = {
              jpg: 'image/jpeg',
              png: 'image/png',
              gif: 'image/gif'
            };
            results = [];
            for (ext in typeMap) {
              mime = typeMap[ext];
              prefix = "data:" + mime + ";base64,";
              if (dataURL.substring(0, prefix.length) === prefix) {
                _this.ext = ext;
                _this.base64 = dataURL.substring(prefix.length);
                $('#the-photo-upload-box').css('background-image', "url(\"" + dataURL + "\")");
                break;
              } else {
                results.push(void 0);
              }
            }
            return results;
          };
        })(this);
        return reader.readAsDataURL(file);
      }
    };

    App.prototype.login = function(name, pw, cb) {
      return this.aris.login(name, pw, (function(_this) {
        return function() {
          $('body').toggleClass('is-logged-in', _this.aris.auth != null);
          _this.checkIfOwner();
          return cb();
        };
      })(this));
    };

    App.prototype.logout = function() {
      this.aris.logout();
      this.checkIfOwner();
      $('body').removeClass('is-logged-in');
      return $('body').removeClass('is-mode-add');
    };

    App.prototype.checkIfOwner = function() {
      var ref, ref1;
      return this.userIsOwner = (this.aris.auth != null) && (((ref = this.game) != null ? ref.owners : void 0) != null) && (ref1 = this.aris.auth.user_id, indexOf.call(this.game.owners.map((function(_this) {
        return function(user) {
          return user.user_id;
        };
      })(this)), ref1) >= 0);
    };

    App.prototype.error = function(s) {
      return console.log("ERROR: " + s);
    };

    App.prototype.warn = function(s) {
      return console.log("Warning: " + s);
    };

    return App;

  })();

  app = new App;

  window.app = app;

}).call(this);
