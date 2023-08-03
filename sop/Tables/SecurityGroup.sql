CREATE TABLE [sop].[SecurityGroup] (
    [SecurityGroupId] INT       IDENTITY (1, 1) NOT NULL,
    [SecurityGroupNm] [sysname] NOT NULL,
    PRIMARY KEY CLUSTERED ([SecurityGroupId] ASC),
    UNIQUE NONCLUSTERED ([SecurityGroupNm] ASC)
);

