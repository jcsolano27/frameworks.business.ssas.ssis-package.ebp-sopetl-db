CREATE FUNCTION [sop].[CONST_ProductId_ProductNodeId]
(
    @ProductNodeId VARCHAR(50)
)
RETURNS INT
AS
BEGIN

    DECLARE @ProductId INT = 0;

    SELECT @ProductId = P.ProductId
    FROM dbo.StgProductHierarchy H
        JOIN sop.Product P
            ON CAST(H.SnOPDemandProductId AS VARCHAR(30)) = P.SourceProductId
               AND P.ProductTypeId =
               (
                   SELECT sop.CONST_ProductTypeId_SnopDemandProduct()
               )
    WHERE H.ProductNodeID = @ProductNodeId;

    RETURN @ProductId;
END;