// Setup for ajax
var basicWebserviceURL = "/webwork2/instructorXMLHandler";
var basicRequestObject = {
    "xml_command":"listLib",
    "pw":"",
    "password":'change-me',
    "session_key":'change-me',
    "user":"user-needs-to-be-defined",
    "library_name":"Library",
    "courseID":'change-me',
    "set":"set0",
    "new_set_name":"new set",
    "command":"searchLib"
};

function init_webservice(command) {
  var myUser = $('#hidden_user').val();
  var myCourseID = $('#hidden_courseID').val();
  var mySessionKey = $('#hidden_key').val();
  var mydefaultRequestObject = {
        };
  _.defaults(mydefaultRequestObject, basicRequestObject);
  if (myUser && mySessionKey && myCourseID) {
    mydefaultRequestObject.user = myUser;
    mydefaultRequestObject.session_key = mySessionKey;
    mydefaultRequestObject.courseID = myCourseID;
  } else {
    alert("missing hidden credentials: user "
      + myUser + " session_key " + mySessionKey+ " courseID "
      + myCourseID, "alert-error");
    return null;
  }
  mydefaultRequestObject.xml_command = command;
  return mydefaultRequestObject;
}


// New object
function tag_widget(id, path) {

  var nodata = {'DBsubject': '', 'DBchapter': '', 'DBsection': ''};

  var $el = $('#'+id);
  $el.html('<b>Edit tags:</b>');
  $el.append('<select id="'+id+'subjects"></select>');
  var subj = $('#'+id+'subjects');
  subj.append('<option value="All Subjects">All Subjects</option>');
  $el.append('<select id="'+id+'chapters"></select>');
  var chap = $('#'+id+'chapters');
  chap.append('<option value="All Chapters">All Chapters</option>');
  $el.append('<select id="'+id+'sections"></select>');
  var sect = $('#'+id+'sections');
  sect.append('<option value="All Sections">All Sections</option>');
  $el.append('<select id="'+id+'level"></select>');
  var levels = $('#'+id+'level');
  levels.append('<option value="">Level</option>');
  for (var j=1; j<7; j++) {
    levels.append('<option value="'+j+'">'+j+'</option>');
  }
  subj.change(function() {tag_widget_clear_message(id);tag_widget_update('chapters', 'get', id, nodata);});
  chap.change(function() {tag_widget_clear_message(id);tag_widget_update('sections', 'get', id, nodata);});
  sect.change(function() {tag_widget_clear_message(id);});
  this.tw_gettags(path, id);
  var savebutton = $el.append('<button id="'+id+'Save">Save</button>');
  $('#'+id+'Save').click(function() {tag_widget_savetags(id, path);return false;});
  $el.append('<span id="'+id+'result"></span>');
  return false;
}

tag_widget.prototype.tw_gettags = function(path, id) {
  var mydefaultRequestObject = init_webservice('getProblemTags');
  // console.log("In tw_gettags");
  if(mydefaultRequestObject == null) {
    // We failed
    return false;
  }
  mydefaultRequestObject.command = path;
  console.log(mydefaultRequestObject);
  return $.post(basicWebserviceURL, mydefaultRequestObject, function (data) {
      var response = $.parseJSON(data);
      var dat = response.result_data;
      console.log(dat);
      tag_widget_update('subjects', 'get', id, dat);
    });
  return true;
}

tag_widget_savetags = function(id, path) {
  var mydefaultRequestObject = init_webservice('setProblemTags');
  if(mydefaultRequestObject == null) {
    // We failed
    return false;
  }
  var subj = $('#'+id+'subjects').find(':selected').text();
  var chap = $('#'+id+'chapters').find(':selected').text();
  var sect = $('#'+id+'sections').find(':selected').text();
  var level = $('#'+id+'level').find(':selected').text();
  if(subj == 'All Subjects') { subj = '';};
  if(chap == 'All Chapters') { chap = '';};
  if(sect == 'All Sections') { sect = '';};
  if(level == 'Level') { level = '';};
  mydefaultRequestObject.library_subjects = subj;
  mydefaultRequestObject.library_chapters = chap;
  mydefaultRequestObject.library_sections = sect;
  mydefaultRequestObject.library_level = level;
  mydefaultRequestObject.command = path;
  console.log(mydefaultRequestObject);
  return $.post(basicWebserviceURL, mydefaultRequestObject, function (data) {
      var response = $.parseJSON(data);
      var mesg = response.server_response;
      console.log(response);
      $('#'+id+'result').text(mesg);
    });
}

tag_widget_clear_message = function(id) {
  $('#'+id+'result').text('');
}

tag_widget_update = function(who, what, where, values) {
  // where is the start of the id's for the parts
  var child = { subjects : 'chapters', chapters : 'sections', sections : 'level', level : 'count'};

// console.log({"who": who, "what": what, "where":where, "values": values});
  var all = 'All ' + capFirstLetter(who);
  if(who=='level') {
    all = 'Level';
  }

  if(who=='count') {
    return false;
  }
  if(!values.DBsubject && values.DBsubject.match(/ZZZ/)) {
     $('#'+where+'subjects').remove();
     $('#'+where+'chapters').remove();
     $('#'+where+'sections').remove();
     $('#'+where+'level').remove();
     $('#'+where+'Save').remove();
     $('#'+where+'result').text(' Problem file is a pointer to another file');
     return false;
  }
  var mydefaultRequestObject = init_webservice('searchLib');
  if(mydefaultRequestObject == null) {
    // We failed
    return false;
  }
  var subj = $('#'+where+'subjects').find(':selected').text();
  var chap = $('#'+where+'chapters').find(':selected').text();
  var sect = $('#'+where+'sections').find(':selected').text();
  var level = $('#'+where+'level').find(':selected').text();
  if(subj == 'All Subjects') { subj = '';};
  if(chap == 'All Chapters') { chap = '';};
  if(sect == 'All Sections') { sect = '';};
  if(level == 'Level') { level = '';};
  // Now override in case we were fed values
  if(values.DBsubject) { subj = values.DBsubject;}
  if(values.DBchapter) { chap = values.DBchapter;}
  if(values.DBsection) { sect = values.DBsection;}
  if(values.Level) { level = values.Level;}
  mydefaultRequestObject.library_subjects = subj;
  mydefaultRequestObject.library_chapters = chap;
  mydefaultRequestObject.library_sections = sect;
  var subcommand = "getAllDBsubjects";
  if(who == 'level') {
    setselectbyid(where+who, ['Level',1,2,3,4,5,6]);
    $('#'+where+who).val(level); 
    return true;
  }
  if(what == 'clear') {
    setselectbyid(where+who, [all]);
    return tag_widget_update(child[who], 'clear',where, values);
  }
  if(who=='chapters' && subj=='') { return tag_widget_update(who, 'clear', where, values); }
  if(who=='sections' && chap=='') { return tag_widget_update(who, 'clear', where, values); }
  if(who=='chapters') { subcommand = "getAllDBchapters";}
  if(who=='sections') { subcommand = "getSectionListings";}
  mydefaultRequestObject.command = subcommand;
  // console.log("Setting menu "+where+who);
  // console.log(mydefaultRequestObject);
  return $.post(basicWebserviceURL, mydefaultRequestObject, function (data) {
      var response = $.parseJSON(data);
      //console.log(response);
      var arr = response.result_data;
      arr.splice(0,0,all);
      setselectbyid(where+who, arr);
      if(values.DBsubject && who=='subjects') { 
        $('#'+where+who).val(values.DBsubject); 
      }
      if(values.DBchapter && who=='chapters') { 
        $('#'+where+who).val(values.DBchapter);
      }
      if(values.DBsection && who=='sections') { 
        $('#'+where+who).val(values.DBsection);
      }
      tag_widget_update(child[who], 'get',where, values);
    });
  return true;
}

// Two utility functions
function setselectbyid(id, newarray) {
  var sel = $('#'+id);
  // console.log("Setting "+id);
  sel.empty();
  $.each(newarray, function(i,val) {
    sel.append($("<option></option>").val(val).html(val));
  });
}

function capFirstLetter(string) {
    return string.charAt(0).toUpperCase() + string.slice(1);
}

