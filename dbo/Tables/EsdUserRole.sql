CREATE TABLE [dbo].[EsdUserRole] (
    [EsdUserRoleId] INT           IDENTITY (1, 1) NOT NULL,
    [UserNm]        NVARCHAR (50) NOT NULL,
    [RoleNm]        NVARCHAR (50) NOT NULL,
    [CreatedOn]     DATETIME      DEFAULT (getdate()) NOT NULL,
    [CreatedBy]     VARCHAR (25)  DEFAULT (original_login()) NOT NULL,
    [UpdatedOn]     DATETIME      DEFAULT (getdate()) NOT NULL,
    [UpdatedBy]     VARCHAR (25)  DEFAULT (original_login()) NOT NULL,
    PRIMARY KEY CLUSTERED ([EsdUserRoleId] ASC)
);

