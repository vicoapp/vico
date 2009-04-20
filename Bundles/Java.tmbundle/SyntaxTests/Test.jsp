<%= expression to be printet %>

<%--
Block Comment
--%>

<%
// some scriptlet code
String name = request.getParameter("name");
if (name != null) {
 %>
 <h1><%= name %></h1>
 <%
} else {
 %>
 <h1 style="color:red">Error!</h1>
<u></u>
 <%
}
%>


<h1 id=""></h1>

<%!
String test = "hej med dig";
int i = 10;
%>

<%!
public class Test {
 private String testerString;

 public Test(String test){
   testerString = test;
 }

 public void getTest() {
   return this.testerString;
 }

}
%>

<%@ page import="java.util.*, java.lang.*" %>
<%@ page buffer="5kb" autoFlush="false" %>
<%@ page errorPage="error.jsp" %>
<%@ include file="relativeURL" %>
<%@ taglib uri="URIToTagLibrary" prefix="somePrefix" %>

<jsp:declaration>
String test = "blah";
</jsp:declaration>
<jsp:scriptlet>
if (test.equals("blah")) {
</jsp:scriptlet>
<jsp:expression>
"expression to be printet: " + test
</jsp:expression>
<jsp:scriptlet>
}
</jsp:scriptlet>