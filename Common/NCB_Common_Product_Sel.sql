DROP PROCEDURE IF EXISTS NCB_Common_Product_Sel;
DELIMITER //

CREATE DEFINER = 'ChatBotSystem'@'%' PROCEDURE  NCB_Common_Product_Sel(
    /*
		Creator: Dominic@20190401
        Param:

        Revisions:
				- 20190401@Dominic: First Commit
                - 20191002@Dominic: Filter enabled products
        
    */
)
SQL SECURITY DEFINER
BEGIN

	SELECT p.ProductId AS ID, p.ProductName AS Name
    FROM Product p
    WHERE p.IsDisabled = 0
    ORDER BY p.ProductName;
    
END;

//
DELIMITER ;
GRANT EXECUTE ON PROCEDURE NCB_Common_Product_Sel TO 'ncb.admin'@'%';