$(document).ready(function() {	
	var autoSaveContent = '';
	
	if (userLanguage == 'de') {
	
		autoSaveContent += '<div id="autoSaveBox">';
		autoSaveContent += '<input type="checkbox" id="enableAutoSave" name="enableAutoSave" value="yes"/>';
		autoSaveContent += '<label for="selectAutoSaveTime">Automatisches Speichern nach</label>';
		autoSaveContent += '<select id="selectAutoSaveTime" name="selectAutoSaveTime">';
		autoSaveContent += '<option value="10000">10 Sekunden</option>';
		autoSaveContent += '<option value="15000" selected="selected">15 Sekunden</option>';
		autoSaveContent += '<option value="30000">30 Sekunden</option>';
		autoSaveContent += '<option value="60000">1 Minute</option>';
		autoSaveContent += '<option value="120000">2 Minuten</option>';
		autoSaveContent += '<option value="300000">5 Minuten</option>';
		autoSaveContent += '</select>';
		autoSaveContent += '<br />';
		autoSaveContent += '</div>';
	
	} else {
		autoSaveContent += '<div id="autoSaveBox">';
		autoSaveContent += '<input type="checkbox" id="enableAutoSave" name="enableAutoSave" value="yes" />';
		autoSaveContent += '<label for="selectAutoSaveTime">Automatic save after</label>';
		autoSaveContent += '<select id="selectAutoSaveTime" name="selectAutoSaveTime">';
		autoSaveContent += '<option value="10000">10 seconds</option>';
		autoSaveContent += '<option value="15000" selected="selected">15 seconds</option>';
		autoSaveContent += '<option value="30000">30 seconds</option>';
		autoSaveContent += '<option value="60000">1 minute</option>';
		autoSaveContent += '<option value="120000">2 minutes</option>';
		autoSaveContent += '<option value="300000">5 minutes</option>';
		autoSaveContent += '</select>';
		autoSaveContent += '<br />';
		autoSaveContent += '</div>';
	}
	
	$('#cancel').after(autoSaveContent);
	
	$('#selectAutoSaveTime').change(setEnableAutosaveTime);
	$('#enableAutoSave').click(setEnableAutosaveTime);
	
	if ($('#enableAutoSave:checked').val()) {
		var autoSaveTime = 15000;
		intervalActive = window.setInterval("saveTopic()", autoSaveTime);
	} else {
		intervalActive = 0;
	}
	
});


function setEnableAutosaveTime() {
	if ($('#enableAutoSave:checked').val()) {
		autoSaveTime=$('#selectAutoSaveTime option:selected').val();
		window.clearInterval(intervalActive);
		intervalActive = window.setInterval("saveTopic()", autoSaveTime);
	} else {
		window.clearInterval(intervalActive);
	}
}

function saveTopic() {
	
	var textTopicTML;
	var displayTopic = $('#topic').css('display');
		
	if (displayTopic == 'none') {
	
		var textTopicWYSIWYG = document.getElementById("mce_editor_0").contentWindow.document.body.innerHTML;
		
		$.post(autoSaveBinPath + "/rest/WysiwygPlugin/html2tml", {text: textTopicWYSIWYG, topic: autoSaveWeb + '.' + autoSaveTopic},
		
		function(data) {
			$('#topic').val(data);
			textTopicTML = $('#topic').val();
			$.post(autoSaveBinPath + "/rest/AutoSavePlugin/autoSaveTopic", {text:textTopicTML, web:autoSaveWeb, topic:autoSaveWeb+'.'+ autoSaveTopic});
		});
	
	} else {
		textTopicTML = $('#topic').val();
		$.post(autoSaveBinPath + "/rest/AutoSavePlugin/autoSaveTopic", {text:textTopicTML, web:autoSaveWeb, topic:autoSaveWeb+'.'+ autoSaveTopic});
	}
}
