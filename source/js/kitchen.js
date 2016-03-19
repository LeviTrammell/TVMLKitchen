/*
 kitchen.js
 Copyright (C) 2015 toshi0383 All Rights Reserved.
*/

var parser;
var currentTab;

/// Presenters
function defaultPresenter(xml) {
    dismissModal();
    if(this.loadingIndicatorVisible) {
        navigationDocument.replaceDocument(xml, this.loadingIndicator);
        this.loadingIndicatorVisible = false;
    } else {
        navigationDocument.pushDocument(xml);
    }
}

function searchPresenter(xml) {

    this.defaultPresenter.call(this, xml);
    var doc = xml;

    var searchField = doc.getElementsByTagName("searchField").item(0);
    var keyboard = searchField.getFeature("Keyboard");

    keyboard.onTextChange = function() {
        var searchText = keyboard.text;
        buildResults(doc, searchText);
    }
}

/**
 *  Displays an XML string as a "document" within a tab.
 *  A new document will be created for the tab if it doesn't exist.
 *
 *  @param xml The XML string to be presented
 *
 *  @return void
 */
function menuBarItemPresenter(xml) {
    var feature = currentTab.parentNode.getFeature("MenuBarDocument");
    if (feature) {
        var currentDoc = feature.getDocument(currentTab);
        if (!currentDoc) {
            feature.setDocument(xml, currentTab);
        }
    }
}

/// Documents presented in the modal view are presented in fullscreen
/// with a semi-transparent background that blurs the document below it.
function modalDialogPresenter(xml) {
    navigationDocument.presentModal(xml);
}

/// Dismisses the current modal window
function dismissModal() {
    navigationDocument.dismissModal();
}

/// Event Handlers
function play(event) {
    var ele = event.target,
        actionID = ele.getAttribute('playActionID');
    if(actionID && typeof playActionIDHandler !== 'undefined'){
        playActionIDHandler(actionID);
        return;
    }
}

function holdselect(event) {
}

function highlight(event) {
}

function load(event) {
    var self = this,
        ele = event.target,
        templateURL = ele.getAttribute("template"),
        presentationType = ele.getAttribute("presentationType"),
        actionID = ele.getAttribute("actionID"),
        menuIndex = ele.getAttribute("menuIndex"),
        tagName = ele.tagName;
    
    
    // If this is a menu item then trigger the relevent handler
    if(menuIndex){
        currentTab = ele;
        tabBarHandler(menuIndex);
    }
    
    if(actionID && typeof actionIDHandler !== 'undefined'){
        actionIDHandler(actionID);
        return;
    }

    if (!templateURL) {
        return;
    }

    loadTemplateFromURL(templateURL, presentationType);
}

/// Create TVML from XML string.
function makeDocument(resource) {
    var doc = parser.parseFromString(resource, "application/xml");
    return doc;
}

function showLoadingIndicator(presentation) {
    if (!this.loadingIndicator) {
        this.loadingIndicator = this.makeDocument(loadingTemplate());
    }

    if (!this.loadingIndicatorVisible &&
        presentation != "modalDialogPresenter" &&
        presentation != "menuBarItemPresenter")
    {
        navigationDocument.pushDocument(this.loadingIndicator);
        this.loadingIndicatorVisible = true;
    }
}

/**
 Show the loading indicator for the presentation type passed from UIKit
 */
function showLoadingIndicatorForType(presentationType) {
    if (presentationType == 1 ||
        presentationType == 2 ||
        this.loadingIndicatorVisible) {
        return;
    }

    if (!this.loadingIndicator) {
        this.loadingIndicator = this.makeDocument(loadingTemplate());
    }

    navigationDocument.pushDocument(this.loadingIndicator);
    this.loadingIndicatorVisible = true;
}

function removeLoadingIndicator() {
    if (this.loadingIndicatorVisible) {
        navigationDocument.removeDocument(this.loadingIndicator);
        this.loadingIndicatorVisible = false;
    }
}

function loadingTemplate() {
    return `<?xml version="1.0" encoding="UTF-8" ?>
        <document>
          <loadingTemplate>
            <activityIndicator>
              <text>Loading...</text>
            </activityIndicator>
          </loadingTemplate>
        </document>`
}

function presenterForType(type) {
    switch(type) {
        case 1:
            return modalDialogPresenter;
        case 2:
            return menuBarItemPresenter;
        default:
            return defaultPresenter;
    }
}

/// load template from Main Bundle URL
/// Expected to be called from native context.
function openTemplateFromXMLString(xmlString, presentationType) {
    showLoadingIndicatorForType(presentationType);
    var doc = makeDocument(xmlString);
    doc.addEventListener("select", load.bind(this));
    doc.addEventListener("highlight", highlight.bind(this));
    doc.addEventListener("holdselect", holdselect.bind(this));
    doc.addEventListener("play", play.bind(this));
    
    presenterForType(presentationType).call(this, doc);
}

App.onLaunch = function(options) {
    App.options = options
    parser = new DOMParser();
}
