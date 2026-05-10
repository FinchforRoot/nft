// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockMyNft is ERC721,ERC721URIStorage,Ownable{

    // Token ID计数器
    uint256 private _tokenIdCounter;
    
    // 最大供应量
    uint256 public constant MAX_SUPPLY = 10000;
    
    // 铸造价格
    uint256 public mintPrice = 0.00001 ether;

    /**
     * NFT熔铸事件
     * @param minter 熔铸人地址
     * @param tokenId 新的NFT的tokenID
     * @param uri 元数据URI
     */
    event NFTMinted(
        address indexed minter,
        uint256 indexed tokenId,
        string uri
    );

    /**
     * 构造函数
     */
    constructor() ERC721("MyNft", "MNFT") Ownable(msg.sender) {}

    /**
     * @dev 检查接口支持
     * @param interfaceId 接口ID
     * @return 是否支持该接口
     * @notice 实现ERC165标准，支持接口查询
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721URIStorage) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 重写tokenURI函数
     * @param tokenId Token ID
     * @return 元数据URI
     * @notice 调用ERC721URIStorage的tokenURI方法
     */
    function tokenURI(uint256 tokenId) public view override(ERC721,ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev 熔铸MYNFT
     * @param uri NFT的元数据信息
     * @return 新tokenId
     */
    function mint(string memory uri) public payable returns (uint256){

        require(_tokenIdCounter < MAX_SUPPLY,"Max supply reached");

        require(msg.value >= mintPrice,"Insufficient payment");

        _tokenIdCounter++;

        uint256 newTokenId = _tokenIdCounter;

        _safeMint(msg.sender, newTokenId);

        _setTokenURI(newTokenId, uri);

        emit NFTMinted(msg.sender, newTokenId, uri);

        return newTokenId;
    }

    /**
     * @dev 查询当前NFT的总熔铸量
     */
    function totalSupply() public view returns (uint256){
        return _tokenIdCounter;
    }

    /**
     * @dev 管理员提取NFT合约中的熔铸手续费
     */
    function withdraw()public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0,"No balance to withdraw");
        (bool success, ) = owner().call{value:balance}("");
        if(!success){
            revert("withdraw fail");
        }
    }
    
        

    
}