/*
	Task: Grant permisions to ncb.hangfire
*/

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, EXECUTE ON ChatBotHangfire.* TO `ncb.hangfire`@`%`;