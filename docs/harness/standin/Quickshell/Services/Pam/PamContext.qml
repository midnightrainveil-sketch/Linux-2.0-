import QtQml
QtObject { property string configDirectory; property string config; property bool responseRequired: false; signal completed(int result); signal error(); function start() {} function respond(s) {} }
