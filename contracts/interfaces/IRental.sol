// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

///  Note: the ERC-165 identifier for this interface is .
interface IRental /* is IERC1155,IERC165 */ {
    /**
     * @notice This emits when user rent NFT
     * @param id The id of the current token
     * @param user The address to rent the NFT usage rights
     * @param amount The amount of usage rights
     * @param expires The specified period of time to rent
     **/
    event Rented(
        uint256 indexed id,
        address indexed user,
        uint256 amount,
        uint256 expires
    );

    /**
     * @notice This emits when the NFT owner takes back the usage rights from the tenant (the `user`) 
     * @param id The id of the current token
     * @param user The address to rent the NFT's usage rights
     * @param amount Amount of usage rights
     **/
    event TakeBack(uint256 indexed id, address indexed user, uint256 amount);

    /**
     * @notice Function to rent out usage rights
     * @param from The address to approve
     * @param to The address to rent the NFT usage rights
     * @param id The id of the current token
     * @param amount The amount of usage rights
     * @param expires The specified period of time to rent
     **/
    function safeRent(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 expires
    ) external;

    /**
     * @notice Function to take back usage rights after the end of the tenancy
     * @param user The address to rent the NFT's usage rights
     * @param tokenId The id of the current token
     **/
    function takeBack(
        address user,
        uint256 tokenId
    ) external;

    /**
    * @notice Return the NFT to the address of the NFT property right owner.
    **/
    function propertyRightOf(uint256 id) external view returns (address);

    /**
    * @notice Return the total supply amount of the current token
    **/
    function totalSupply(uint256 id) external view returns (uint256);

    
}